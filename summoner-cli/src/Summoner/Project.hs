{- |
Module                  : Summoner.Project
Copyright               : (c) 2017-2021 Kowainik
SPDX-License-Identifier : MPL-2.0
Maintainer              : Kowainik <xrom.xkov@gmail.com>
Stability               : Stable
Portability             : Portable

This module introduces functions for the project creation.
-}

{- HLINT ignore "Reduce duplication" -}

module Summoner.Project
       ( generateProject
       , generateProjectInteractive
       , generateProjectNonInteractive
       , initializeProject
       ) where

import Colourista (bold, errorMessage, formattedMessage, green, infoMessage, skipMessage,
                   successMessage, warningMessage)
import Data.List.NonEmpty ((<|))
import Shellmet (($?))
import System.Directory (findExecutable, setCurrentDirectory)

import Summoner.Config (Config, ConfigP (..))
import Summoner.CustomPrelude (CustomPrelude (..))
import Summoner.Decision (Decision (..), decisionToBool, decisionsToBools, promptDecisionToBool)
import Summoner.Default (currentYear, defaultDescription, defaultGHC)
import Summoner.GhcVer (parseGhcVer, showGhcVer)
import Summoner.License (LicenseName (..), fetchLicenseCustom, licenseShortDesc, parseLicenseName)
import Summoner.Mode (ConnectMode (..), Interactivity (..), isOffline)
import Summoner.Question (YesNoPrompt (..), checkUniqueName, choose, doesExistProjectName,
                          falseMessage, mkDefaultYesNoPrompt, query, queryDef,
                          queryManyRepeatOnFail, queryWithPredicate, targetMessageWithText,
                          trueMessage)
import Summoner.Settings (Settings (..))
import Summoner.Source (fetchSources)
import Summoner.Template (createProjectTemplate)
import Summoner.Text (intercalateMap, moduleNameValid, packageNameValid, packageToModule)
import Summoner.Tree (showBoldTree, traverseTree)

import qualified Data.List.NonEmpty as NE


-- | Generate the project.
generateProject
    :: Interactivity  -- ^ Is it interactive or non-interactive mode?
    -> ConnectMode    -- ^ @offline@ mode option.
    -> Text           -- ^ Given project name.
    -> Config         -- ^ Given configurations.
    -> IO ()
generateProject Interactive    = generateProjectInteractive
generateProject NonInteractive = generateProjectNonInteractive


-- | Generate the project.
generateProjectInteractive
    :: ConnectMode    -- ^ @offline@ mode option.
    -> Text           -- ^ Given project name.
    -> Config         -- ^ Given configurations.
    -> IO ()
generateProjectInteractive connectMode projectName ConfigP{..} = do
    settingsRepo <- checkUniqueName projectName
    -- decide cabal stack or both
    (settingsCabal, settingsStack) <- getCabalStack (cCabal, cStack)

    settingsOwner       <- queryDef "Repository owner: " cOwner
    settingsDescription <- queryDef "Short project description: " defaultDescription
    settingsFullName    <- queryDef "Author: " cFullName
    settingsEmail       <- queryDef "Maintainer e-mail: " cEmail

    putText categoryText
    settingsCategories <- query "Category: "

    putText licenseText
    settingsLicenseName  <- if isOffline connectMode
        then NONE <$ infoMessage "'NONE' license is used in offline mode"
        else choose parseLicenseName "License: " $ NE.nub (cLicense <| universeNonEmpty)

    -- License creation
    settingsYear <- currentYear
    settingsLicenseText <- fetchLicenseCustom
        settingsLicenseName
        settingsFullName
        settingsYear

    settingsGitHub   <- promptDecisionToBool cGitHub
        (YesNoPrompt "GitHub integration" "Do you want to create a GitHub repository?")

    let settingsNoUpload = getAny cNoUpload
    when settingsNoUpload $ do
        infoMessage "'No upload' option is selected. The project won't be uploaded to GitHub."
        infoMessage "Use 'gh' and 'git' commands manually in order to upload the project to GitHub"
    settingsPrivate  <- decisionIf
        (settingsGitHub && not settingsNoUpload)
        (YesNoPrompt "private repository" "Create as a private repository (Requires a GitHub private repo plan)?")
        cPrivate
    settingsGhActions <- decisionIf settingsGitHub (mkDefaultYesNoPrompt "GitHub Actions CI integration") cGhActions
    settingsTravis    <- decisionIf settingsGitHub (mkDefaultYesNoPrompt "Travis CI integration") cTravis
    settingsAppVeyor  <- decisionIf settingsGitHub (mkDefaultYesNoPrompt "AppVeyor CI integration") cAppVey
    settingsIsLib     <- promptDecisionToBool cLib (mkDefaultYesNoPrompt "library target")
    settingsIsExe     <- let target = "executable target" in
        if settingsIsLib
        then promptDecisionToBool cExe (mkDefaultYesNoPrompt target)
        else trueMessage target
    settingsTest      <- promptDecisionToBool cTest (mkDefaultYesNoPrompt "tests")
    settingsBench     <- promptDecisionToBool cBench (mkDefaultYesNoPrompt "benchmarks")
    settingsPrelude   <- getPrelude

    let settingsExtensions = cExtensions
    let settingsGhcOptions = cGhcOptions
    let settingsGitignore = cGitignore


    putTextLn $ "The project will be created with GHC-" <> showGhcVer defaultGHC
    settingsTestedVersions <- sortNub . (defaultGHC :) <$> case cGhcVer of
        [] -> do
            putTextLn "Additionally you can specify versions of GHC to test with (space-separated): "
            infoMessage $ "Supported by 'summoner' GHCs: " <> intercalateMap " " showGhcVer universe
            queryManyRepeatOnFail parseGhcVer
        vers -> do
            putTextLn $ "Also these GHC versions will be added: " <> intercalateMap " " showGhcVer vers
            pure vers

    settingsFiles <- fetchSources connectMode cFiles

    -- Create project data from all variables in scope
    -- and make a project from it.
    initializeProject Settings{..}
 where
    decisionIf :: Bool -> YesNoPrompt -> Decision -> IO Bool
    decisionIf p ynPrompt decision = if p
        then promptDecisionToBool decision ynPrompt
        else falseMessage (yesNoTarget ynPrompt)

    categoryText :: Text
    categoryText = unlines
        [ "List of categories to choose from:"
        , ""
        , "  * Control                    * Concurrency"
        , "  * Codec                      * Graphics"
        , "  * Data                       * Sound"
        , "  * Math                       * System"
        , "  * Parsing                    * Network"
        , "  * Text"
        , ""
        , "  * Application                * Development"
        , "  * Compilers/Interpreters     * Testing"
        , "  * Web"
        , "  * Game"
        , "  * Utility"
        , ""
        ]

    licenseText :: Text
    licenseText = "List of licenses to choose from:\n\n"
        <> unlines (map showShort $ universe @LicenseName)
        <> "\n"
      where
        showShort :: LicenseName -> Text
        showShort l = "  * " <> show l <> ": " <> licenseShortDesc l

    getPrelude :: IO (Maybe CustomPrelude)
    getPrelude = case cPrelude of
        Last Nothing -> do
            p <- queryWithPredicate
                "Custom prelude package (leave empty if no custom prelude is needed): "
                []
                "Name can contain letters/numbers/'-'"
                packageNameValid
            if p == "" then Nothing <$ skipMessage "No custom prelude will be used in the project"
            else do
                let defModule = packageToModule p
                input <- queryWithPredicate
                    "Custom prelude module: "
                    [defModule]
                    "Name can contain dot-separated capitalized letter/numeral fragments. Ex: This.Is.Valid1"
                    moduleNameValid
                let m = if input == "" then defModule else input
                successMessage $ "Custom prelude " <> p <> " will be used in the project"
                pure $ Just $ CustomPrelude p m
        Last prelude@(Just (CustomPrelude p _)) ->
            prelude <$ successMessage ("Custom prelude " <> p <> " will be used in the project")

    -- get what build tool to use in the project
    -- If user chose only one during CLI, we assume to use only that one.
    getCabalStack :: (Decision, Decision) -> IO (Bool, Bool)
    getCabalStack = \case
        (Idk, Idk) -> promptDecisionToBool cCabal (mkDefaultYesNoPrompt "cabal") >>= \c ->
            if c then promptDecisionToBool cStack (mkDefaultYesNoPrompt "stack") >>= \s -> pure (c, s)
            else stackMsg True >> pure (False, True)
        (Nop, Nop) -> errorMessage "Neither cabal nor stack was chosen" >> exitFailure
        (Yes, Yes) -> output (True, True)
        (Yes, _)   -> output (True, False)
        (_, Yes)   -> output (False, True)
        (Nop, Idk) -> output (False, True)
        (Idk, Nop) -> output (True, False)
      where
        output :: (Bool, Bool) -> IO (Bool, Bool)
        output x@(c, s) = cabalMsg c >> stackMsg s >> pure x

        cabalMsg c = targetMessageWithText c "Cabal" "used in this project"
        stackMsg c = targetMessageWithText c "Stack" "used in this project"

----------------------------------------------------------------------------
-- Non-interactive
----------------------------------------------------------------------------

generateProjectNonInteractive
    :: ConnectMode    -- ^ @offline@ mode option.
    -> Text           -- ^ Given project name.
    -> Config         -- ^ Given configurations.
    -> IO ()
generateProjectNonInteractive connectMode projectName ConfigP{..} = do
    isNonUnique <- doesExistProjectName projectName
    when isNonUnique $ do
        errorMessage "Project with this name is already exist. Please choose another one."
        exitFailure
    let settingsRepo = projectName
    -- decide cabal stack or both
    let (settingsCabal, settingsStack) = decisionsToBools (cCabal, cStack)

    let settingsOwner       = cOwner
    let settingsDescription = defaultDescription
    let settingsFullName    = cFullName
    let settingsEmail       = cEmail
    let settingsCategories  = ""
    let settingsLicenseName = if isOffline connectMode then NONE else cLicense

    -- License creation
    settingsYear <- currentYear
    settingsLicenseText <- fetchLicenseCustom
        settingsLicenseName
        settingsFullName
        settingsYear

    let settingsGitHub   = decisionToBool cGitHub
    let settingsNoUpload = getAny cNoUpload || isOffline connectMode

    let settingsPrivate = decisionIf (settingsGitHub && not settingsNoUpload) cPrivate
    let settingsGhActions = decisionIf (settingsCabal && settingsGitHub) cGhActions
    let settingsTravis    = decisionIf settingsGitHub cTravis
    let settingsAppVeyor  = decisionIf settingsGitHub cAppVey
    let (settingsIsLib, settingsIsExe) = decisionsToBools (cLib, cExe)
    let settingsTest    = decisionToBool cTest
    let settingsBench   = decisionToBool cBench
    let settingsPrelude = getLast cPrelude

    let settingsExtensions = cExtensions
    let settingsGhcOptions = cGhcOptions
    let settingsGitignore  = cGitignore
    let settingsTestedVersions = sortNub $ defaultGHC : cGhcVer
    settingsFiles <- fetchSources connectMode cFiles

    -- Create project data from all variables in scope
    -- and make a project from it.
    initializeProject Settings{..}
  where
    decisionIf :: Bool -> Decision -> Bool
    decisionIf p d = p && decisionToBool d

----------------------------------------------------------------------------
-- Initialize
----------------------------------------------------------------------------

-- | Creates the directory and run GitHub commands.
initializeProject :: Settings -> IO ()
initializeProject settings@Settings{..} = do
    createProjectDirectory settings
    when settingsGitHub $ doGithubCommands settings
    formattedMessage [bold, green] "\nJob's done"

-- | From the given 'Settings' creates the project.
createProjectDirectory :: Settings -> IO ()
createProjectDirectory settings@Settings{..} = do
    let tree = createProjectTemplate settings
    traverseTree tree
    successMessage "The project with the following structure has been created:"
    putTextLn $ showBoldTree tree
    setCurrentDirectory (toString settingsRepo)

-- | Init, commit and push repository to GitHub.
doGithubCommands :: Settings -> IO ()
doGithubCommands Settings{..} = do
    -- Create git repostitory and do a commit.
    "git" ["init", "--initial-branch=main"]
    "git" ["add", "."]
    "git" ["commit", "-m", "Create the project"]
    unless settingsNoUpload $ do
        let repo = settingsOwner <> "/" <> settingsRepo
        ghInstalled <- findExecutable "gh"
        case ghInstalled of
            Just _ -> do
                isGhSuccess <- runGh repo
                if isGhSuccess
                then do
                    "git" ["push", "-u", "origin", "main"]
                    "git" ["remote", "set-head", "origin", "-a"]
                    successMessage "Project created:"
                    infoMessage $ "    https://github.com/" <> repo
                else do
                    warningMessage "Error running 'gh'. Possible reason: incorrect password."
                    ghHelp repo
            Nothing -> do
                warningMessage "'gh' is not found at this machine. Cannot create the GitHub repository."
                warningMessage "Please install 'gh' for the proper work of Summoner."
                ghHelp repo
  where
    -- Create repo on GitHub and return 'True' in case of sucsess
    runGh :: Text -> IO Bool
    runGh repo =
        True <$ "gh" (["repo", "create", "-y", "-d", settingsDescription, repo]
             ++ [privateOrPublicFlag settingsPrivate])  -- Create private repository if asked so
             $? pure False

    ghHelp :: Text -> IO ()
    ghHelp repo = do
        infoMessage "To finish the process manually you can run the following command:"
        putTextLn $ "    $ gh repo create -d '" <> settingsDescription <> "' " <> repo <> " " <> privateOrPublicFlag settingsPrivate
    
    privateOrPublicFlag :: Bool -> Text
    privateOrPublicFlag sp = if sp then "--private" else "--public"
