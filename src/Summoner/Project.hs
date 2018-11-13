{-# LANGUAGE QuasiQuotes #-}

-- | This module introduces functional for project creation.

module Summoner.Project
       ( generateProject
       ) where

import NeatInterpolation (text)
import System.Directory (setCurrentDirectory)

import Summoner.Ansi (errorMessage, infoMessage, successMessage)
import Summoner.Config (Config, ConfigP (..))
import Summoner.Decision (Decision (..), decisionToBool)
import Summoner.Default (currentYear, defaultGHC)
import Summoner.GhcVer (parseGhcVer, showGhcVer)
import Summoner.License (LicenseName, customizeLicense, fetchLicense, licenseShortDesc,
                         parseLicenseName)
import Summoner.Process ()
import Summoner.Question (checkUniqueName, choose, chooseYesNo, falseMessage, query, queryDef,
                          queryManyRepeatOnFail, targetMessageWithText, trueMessage)
import Summoner.Question.Data (YesNoPrompt (..), mkDefaultYesNoPrompt, mkYesNoPrompt)
import Summoner.Settings (CustomPrelude (..), Settings (..))
import Summoner.Source (fetchSource)
import Summoner.Template (createProjectTemplate)
import Summoner.Text (intercalateMap, packageToModule)
import Summoner.Tree (showTree, traverseTree)

-- | Generate the project.
generateProject :: Bool -> Text -> Config -> IO ()
generateProject noUpload projectName Config{..} = do
    settingsRepo   <- checkUniqueName projectName
    -- decide cabal stack or both
    (settingsCabal, settingsStack) <- getCabalStack (cCabal, cStack)

    settingsOwner       <- queryDef "Repository owner: " cOwner
    settingsDescription <- query "Short project description: "
    settingsFullName    <- queryDef "Author: " cFullName
    settingsEmail       <- queryDef "Maintainer e-mail: " cEmail

    putText categoryText
    settingsCategories <- query "Category: "

    putText licenseText
    settingsLicenseName  <- choose parseLicenseName "License: " $ ordNub (cLicense : universe)

    -- License creation
    fetchedLicense <- fetchLicense settingsLicenseName
    settingsYear <- currentYear
    let settingsLicenseText = customizeLicense  -- TODO: use named here as well
            settingsLicenseName
            fetchedLicense
            settingsFullName
            settingsYear

    -- Library/Executable/Tests/Benchmarks flags
    settingsGitHub   <- decisionToBool cGitHub (mkYesNoPrompt "GitHub integration" "Do you want to create a GitHub repository?")
    settingsPrivat   <- ifGithub (settingsGitHub && not noUpload) (mkYesNoPrompt "private repository" "Create as a private repository (Requires a GitHub private repo plan)?") cPrivate
    settingsTravis   <- ifGithub settingsGitHub (mkDefaultYesNoPrompt "Travis CI integration") cTravis
    settingsAppVeyor <- ifGithub (settingsStack && settingsGitHub) (mkDefaultYesNoPrompt "AppVeyor CI integration") cAppVey
    settingsIsLib    <- decisionToBool cLib (mkDefaultYesNoPrompt "library target")
    settingsIsExe    <- let target = "executable target" in
              if settingsIsLib
              then decisionToBool cExe (mkDefaultYesNoPrompt target)
              else trueMessage target
    settingsTest   <- decisionToBool cTest (mkDefaultYesNoPrompt "tests")
    settingsBench  <- decisionToBool cBench (mkDefaultYesNoPrompt "benchmarks")
    settingsPrelude <- if settingsIsLib then getPrelude else pure Nothing
    let settingsBaseType = case settingsPrelude of
            Nothing -> "base"
            Just _  -> "base-noprelude"

    let settingsExtensions = cExtensions
    let settingsWarnings = cWarnings

    putTextLn $ "The project will be created with the latest resolver for default GHC-" <> showGhcVer defaultGHC
    settingsTestedVersions <- sortNub . (defaultGHC :) <$> case cGhcVer of
        [] -> do
            putTextLn "Additionally you can specify versions of GHC to test with (space-separated): "
            infoMessage $ "Supported by 'summoner' GHCs: " <> intercalateMap " " showGhcVer universe
            queryManyRepeatOnFail parseGhcVer
        vers -> do
            putTextLn $ "Also these GHC versions will be added: " <> intercalateMap " " showGhcVer vers
            pure vers

    let fetchLast = maybe (pure Nothing) fetchSource . getLast
    settingsStylish      <- fetchLast cStylish
    settingsContributing <- fetchLast cContributing

    -- Create project data from all variables in scope
    let settings = Settings{..}

    createProjectDirectory settings
    -- Create github repository, commit, optionally push and make it private
    when settingsGitHub $ doGithubCommands settings settingsPrivat

 where
    ifGithub :: Bool -> YesNoPrompt -> Decision -> IO Bool
    ifGithub github ynPrompt decision = if github
        then decisionToBool decision ynPrompt
        else falseMessage (yesno_target ynPrompt)

    createProjectDirectory :: Settings -> IO ()
    createProjectDirectory settings@Settings{..} = do
        let tree = createProjectTemplate settings
        traverseTree tree
        successMessage "\nThe project with the following structure has been created:"
        putTextLn $ showTree tree
        setCurrentDirectory (toString settingsRepo)

    doGithubCommands :: Settings -> Bool -> IO ()
    doGithubCommands Settings{..} private = do
        -- Create git repostitory and do a commit.
        "git" ["init"]
        "git" ["add", "."]
        "git" ["commit", "-m", "Create the project"]
        unless noUpload $ do
            "hub" $ ["create", "-d", settingsDescription, settingsOwner <> "/" <> settingsRepo]
                    ++ ["-p" | private]  -- Create private repository if asked so
             -- Upload repository to GitHub.
            "git" ["push", "-u", "origin", "master"]

    categoryText :: Text
    categoryText =
        [text|
        List of categories to choose from:

          * Control                    * Concurrency
          * Codec                      * Graphics
          * Data                       * Sound
          * Math                       * System
          * Parsing                    * Network
          * Text

          * Application                * Development
          * Compilers/Interpreters     * Testing
          * Web
          * Game
          * Utility

        |]

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
            let yesDo, noDo :: IO (Maybe CustomPrelude)
                yesDo = do
                    p <- query "Custom prelude package: "
                    m <- queryDef "Custom prelude module: " (packageToModule p)
                    successMessage $ "Custom prelude " <> p <> " will be used in the project"
                    pure $ Just $ CustomPrelude p m
                noDo = pure Nothing
            chooseYesNo (mkDefaultYesNoPrompt "custom prelude") yesDo noDo
        Last prelude@(Just (CustomPrelude p _)) ->
            prelude <$ successMessage ("Custom prelude " <> p <> " will be used in the project")

    -- get what build tool to use in the project
    -- If user chose only one during CLI, we assume to use only that one.
    getCabalStack :: (Decision, Decision) -> IO (Bool, Bool)
    getCabalStack = \case
        (Idk, Idk) -> decisionToBool cCabal (mkDefaultYesNoPrompt "cabal") >>= \c ->
            if c then decisionToBool cStack (mkDefaultYesNoPrompt "stack") >>= \s -> pure (c, s)
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
