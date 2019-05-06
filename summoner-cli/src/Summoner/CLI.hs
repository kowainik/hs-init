{-# LANGUAGE ApplicativeDo   #-}
{-# LANGUAGE QuasiQuotes     #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections   #-}

-- | This module contains functions and data types to parse CLI inputs.

module Summoner.CLI
       ( -- * CLI data types
         Command (..)
       , NewOpts (..)
       , ShowOpts (..)

         -- * Functions to parse CLI arguments and run @summoner@
       , summon
       , summonCli

         -- * Runners
       , runScript

         -- * Common helper functions
       , getFinalConfig
       ) where

import Data.Version (Version, showVersion)
import Development.GitRev (gitCommitDate, gitDirty, gitHash)
import NeatInterpolation (text)
import Options.Applicative (Parser, ParserInfo, argument, command, execParser, flag, fullDesc, help,
                            helper, info, infoFooter, infoHeader, infoOption, long, maybeReader,
                            metavar, option, progDesc, short, strArgument, strOption,
                            subparser, switch, value)
import Options.Applicative.Help.Chunk (stringChunk)
import Shellmet (($?), ($|))
import System.Directory (doesFileExist)
import System.Info (os)

import Summoner.Ansi (blueCode, boldCode, errorMessage, infoMessage, redCode, resetCode,
                      successMessage, warningMessage)
import Summoner.Config (Config, ConfigP (..), PartialConfig, defaultConfig, finalise,
                        loadFileConfig)
import Summoner.Decision (Decision (..))
import Summoner.Default (defaultConfigFile, defaultGHC)
import Summoner.GhcVer (GhcVer, parseGhcVer, showGhcVer)
import Summoner.License (License (..), LicenseName (..), fetchLicense, parseLicenseName,
                         showLicenseWithDesc)
import Summoner.Project (generateProject)
import Summoner.Settings (CustomPrelude (..), Tool, parseTool)
import Summoner.Template.Script (scriptFile)

import qualified Data.Semigroup as S
import qualified Data.Text as T
import qualified Paths_summoner as Meta (version)


-- | Main function that parses @CLI@ commands and runs them using given
-- 'Command' handler.
summon :: Version -> (Command -> IO ()) -> IO ()
summon version performCommand = execParser (cliParser version) >>= performCommand

-- | Runs @summoner@ in CLI mode.
summonCli :: IO ()
summonCli = summon Meta.version runCliCommand

-- | Run 'summoner' with @CLI@ command
runCliCommand :: Command -> IO ()
runCliCommand = \case
    New opts -> runNew opts
    Script opts -> runScript opts
    ShowInfo opts -> runShow opts

{- | Runs @show@ command.

@
Usage:
  summon show COMMAND
      Show supported licenses or ghc versions

Available commands:
  ghc                      Show available ghc versions
  license                  Show available licenses
  license [LICENSE_NAME]   Show specific license text
@

-}
runShow :: ShowOpts -> IO ()
runShow = \case
    -- show list of all available GHC versions
    GhcList -> showBulletList @GhcVer showGhcVer (reverse universe)
    -- show a list of all available licenses
    LicenseList Nothing -> showBulletList @LicenseName showLicenseWithDesc universe
    -- show a specific license
    LicenseList (Just name) ->
        case parseLicenseName (toText name) of
            Nothing -> do
                errorMessage "This wasn't a valid choice."
                infoMessage "Here is the list of supported licenses:"
                showBulletList @LicenseName show universe
                -- get and show a license`s text
            Just licenseName -> do
                fetchedLicense <- fetchLicense licenseName
                putTextLn $ unLicense fetchedLicense
  where
    showBulletList :: (a -> Text) -> [a] -> IO ()
    showBulletList showT = mapM_ (infoMessage . T.append "➤ " . showT)

{- | Runs @script@ command.

@
Usage: summon script BUILD_TOOL (-g|--ghc GHC_VERSION) (-n|--name FILE_NAME)
  Create a new Haskell script

Available options:
  -h,--help                Show this help text
  -g,--ghc GHC_VERSION     Version of the compiler to be used for script
  -n,--name FILE_NAME      Name of the script file
@
-}
runScript :: ScriptOpts -> IO ()
runScript ScriptOpts{..} = do
    let pathTxt = toText scriptOptsName
    whenM (doesFileExist scriptOptsName) $ do
        errorMessage $ "File already exists: " <> pathTxt
        exitFailure

    let script = scriptFile scriptOptsGhc scriptOptsTool
    writeFileText scriptOptsName script
    unless (os == "mingw32") $
        "chmod" ["+x", pathTxt]
    successMessage $ "Successfully created script: " <> pathTxt

{- | Runs @new@ command.

@
Usage:
  summon new PROJECT_NAME [--ignore-config] [--no-upload] [--offline]
             [-f|--file FILENAME]
             [--cabal]
             [--stack]
             [--prelude-package PACKAGE_NAME]
             [--prelude-module MODULE_NAME]
             [with [OPTIONS]]
             [without [OPTIONS]]
@

-}
runNew :: NewOpts -> IO ()
runNew newOpts@NewOpts{..} = do
    -- get the final config
    finalConfig <- getFinalConfig newOpts
    -- Generate the project.
    generateProject newOptsOffline newOptsProjectName finalConfig

-- | By the given 'NewOpts' return the final configurations.
getFinalConfig :: NewOpts -> IO Config
getFinalConfig NewOpts{..} = do
    -- read config from file
    fileConfig <- readFileConfig newOptsIgnoreFile newOptsConfigFile

    -- guess config from the global ~/.gitconfig file
    gitConfig <- guessFromGit

    -- union all possible configs
    let unionConfig = defaultConfig <> gitConfig <> fileConfig <> newOptsCliConfig

    -- get the final config
    case finalise unionConfig of
        Success c    -> pure c
        Failure msgs -> for_ msgs errorMessage >> exitFailure
  where
    guessFromGit :: IO PartialConfig
    guessFromGit = do
       gitOwner <- (Just <$> "git" $| ["config", "user.login"]) $? pure Nothing
       gitName  <- (Just <$> "git" $| ["config", "user.name"])  $? pure Nothing
       gitEmail <- (Just <$> "git" $| ["config", "user.email"]) $? pure Nothing
       pure $ defaultConfig
           { cOwner = S.Last <$> gitOwner
           , cFullName = S.Last <$> gitName
           , cEmail = S.Last <$> gitEmail
           }


-- | Reads and parses the given config file. If no file is provided the default
-- configuration returned.
readFileConfig :: Bool -> Maybe FilePath -> IO PartialConfig
readFileConfig ignoreFile maybeFile = if ignoreFile then pure mempty else do
    (isDefault, file) <- case maybeFile of
        Nothing -> (True,) <$> defaultConfigFile
        Just x  -> pure (False, x)

    isFile <- doesFileExist file

    if isFile then do
        infoMessage $ "Configurations from " <> toText file <> " will be used."
        loadFileConfig file
    else if isDefault then do
        fp <- toText <$> defaultConfigFile
        warningMessage $ "Default config " <> fp <> " file is missing."
        pure mempty
    else do
        errorMessage $ "Specified configuration file " <> toText file <> " is not found."
        exitFailure

----------------------------------------------------------------------------
-- Command data types
----------------------------------------------------------------------------

-- | Represent all available commands
data Command
    -- | @new@ command creates a new project
    = New NewOpts
    -- | @script@ command creates Haskell script
    | Script ScriptOpts
    -- | @show@ command shows supported licenses or GHC versions
    | ShowInfo ShowOpts

-- | Options parsed with @new@ command
data NewOpts = NewOpts
    { newOptsProjectName :: Text           -- ^ project name
    , newOptsIgnoreFile  :: Bool           -- ^ ignore all config files if 'True'
    , newOptsOffline     :: Bool           -- ^ Offline mode
    , newOptsConfigFile  :: Maybe FilePath -- ^ file with custom configuration
    , newOptsCliConfig   :: PartialConfig  -- ^ config gathered during CLI
    }

-- | Options parsed with @script@ command
data ScriptOpts = ScriptOpts
    { scriptOptsTool :: !Tool      -- ^ Build tool: `cabal` or `stack`
    , scriptOptsName :: !FilePath  -- ^ File path to the script
    , scriptOptsGhc  :: !GhcVer    -- ^ GHC version for this script
    }

-- | Commands parsed with @show@ command
data ShowOpts
    = GhcList
    | LicenseList (Maybe String)

----------------------------------------------------------------------------
-- Parsers
----------------------------------------------------------------------------

-- | Main parser of the app.
cliParser :: Version -> ParserInfo Command
cliParser version = modifyHeader
     $ modifyFooter
     $ info ( helper <*> versionP version <*> summonerP )
            $ fullDesc
           <> progDesc "Set up your own Haskell project"

versionP :: Version -> Parser (a -> a)
versionP version = infoOption (summonerVersion version)
    $ long "version"
   <> short 'v'
   <> help "Show summoner's version"

summonerVersion :: Version -> String
summonerVersion version = toString
    $ intercalate "\n"
    $ [sVersion, sHash, sDate] ++ [sDirty | $(gitDirty)]
  where
    sVersion = blueCode <> boldCode <> "Summoner " <> "v" <>  showVersion version <> resetCode
    sHash = " ➤ " <> blueCode <> boldCode <> "Git revision: " <> resetCode <> $(gitHash)
    sDate = " ➤ " <> blueCode <> boldCode <> "Commit date:  " <> resetCode <> $(gitCommitDate)
    sDirty = redCode <> "There are non-committed files." <> resetCode

-- All possible commands.
summonerP :: Parser Command
summonerP = subparser
    $ command "new" (info (helper <*> newP) $ progDesc "Create a new Haskell project")
   <> command "script" (info (helper <*> scriptP) $ progDesc "Create a new Haskell script")
   <> command "show" (info (helper <*> showP) $ progDesc "Show supported licenses or ghc versions")

----------------------------------------------------------------------------
-- @show@ command parsers
----------------------------------------------------------------------------

-- | Parses options of the @show@ command.
showP :: Parser Command
showP = ShowInfo <$> subparser
    ( command "ghc" (info (helper <*> pure GhcList) $ progDesc "Show supported ghc versions")
   <> command "license" (info (helper <*> licenseText) $ progDesc "Show supported licenses")
    )

licenseText :: Parser ShowOpts
licenseText = LicenseList <$> optional
    (strArgument (metavar "LICENSE_NAME" <> help "Show specific license text"))

----------------------------------------------------------------------------
-- @script@ command parsers
----------------------------------------------------------------------------

-- | Parses options of the @script@ command.
scriptP :: Parser Command
scriptP = do
    scriptOptsTool <- toolArgP
    scriptOptsGhc  <- ghcVerP
    scriptOptsName <- strOption
         $ long "name"
        <> short 'n'
        <> value "my_script"
        <> metavar "FILE_NAME"
        <> help "Name of the script file"

    pure $ Script ScriptOpts{..}

-- | Argument parser for 'Tool'.
toolArgP :: Parser Tool
toolArgP = argument
    (maybeReader $ parseTool . toText)
    (metavar "BUILD_TOOL")

ghcVerP :: Parser GhcVer
ghcVerP = option
    (maybeReader $ parseGhcVer . toText)
    (  long "ghc"
    <> short 'g'
    <> value defaultGHC
    <> metavar "GHC_VERSION"
    <> help "Version of the compiler to be used for script"
    )

----------------------------------------------------------------------------
-- @new@ command parsers
----------------------------------------------------------------------------

-- | Parses options of the @new@ command.
newP :: Parser Command
newP = do
    newOptsProjectName <- strArgument (metavar "PROJECT_NAME")
    newOptsIgnoreFile  <- ignoreFileP
    noUpload           <- noUploadP
    newOptsOffline     <- offlineP
    newOptsConfigFile  <- optional fileP
    cabal <- cabalP
    stack <- stackP
    preludePack <- optional preludePackP
    preludeMod  <- optional preludeModP
    with    <- optional withP
    without <- optional withoutP

    pure $ New $ NewOpts
        { newOptsCliConfig = (maybeToMonoid $ with <> without)
            { cPrelude = fmap S.Last $ CustomPrelude <$> preludePack <*> preludeMod
            , cCabal = cabal
            , cStack = stack
            , cNoUpload = Any $ noUpload || newOptsOffline
            }
        , ..
        }

targetsP ::  Decision -> Parser PartialConfig
targetsP d = do
    cGitHub  <- githubP    d
    cTravis  <- travisP    d
    cAppVey  <- appVeyorP  d
    cPrivate <- privateP   d
    cLib     <- libraryP   d
    cExe     <- execP      d
    cTest    <- testP      d
    cBench   <- benchmarkP d
    pure mempty
        { cGitHub = cGitHub
        , cTravis = cTravis
        , cAppVey = cAppVey
        , cPrivate= cPrivate
        , cLib    = cLib
        , cExe    = cExe
        , cTest   = cTest
        , cBench  = cBench
        }

githubP :: Decision -> Parser Decision
githubP d = flag Idk d
          $ long "github"
         <> short 'g'
         <> help "GitHub integration"

travisP :: Decision -> Parser Decision
travisP d = flag Idk d
          $ long "travis"
         <> short 'c'
         <> help "Travis CI integration"

appVeyorP :: Decision -> Parser Decision
appVeyorP d = flag Idk d
            $ long "app-veyor"
           <> short 'w'
           <> help "AppVeyor CI integration"

privateP :: Decision -> Parser Decision
privateP d = flag Idk d
           $ long "private"
          <> short 'p'
          <> help "Private repository"

libraryP :: Decision -> Parser Decision
libraryP d = flag Idk d
           $ long "library"
          <> short 'l'
          <> help "Library folder"

execP :: Decision -> Parser Decision
execP d = flag Idk d
        $ long "exec"
       <> short 'e'
       <> help "Executable target"

testP :: Decision -> Parser Decision
testP d = flag Idk d
        $ long "test"
       <> short 't'
       <> help "Test target"

benchmarkP :: Decision -> Parser Decision
benchmarkP d = flag Idk d
             $ long "benchmark"
            <> short 'b'
            <> help "Benchmarks"

withP :: Parser PartialConfig
withP = subparser $ mconcat
    [ metavar "with [OPTIONS]"
    , command "with" $ info (helper <*> targetsP Yes) (progDesc "Specify options to enable")
    ]

withoutP :: Parser PartialConfig
withoutP = subparser $ mconcat
    [ metavar "without [OPTIONS]"
    , command "without" $ info (helper <*> targetsP Nop) (progDesc "Specify options to disable")
    ]

ignoreFileP :: Parser Bool
ignoreFileP = switch $ long "ignore-config" <> help "Ignore configuration file"

noUploadP :: Parser Bool
noUploadP = switch $ long "no-upload" <> help "Do not upload to GitHub. Special case of the '--offline' flag."

offlineP :: Parser Bool
offlineP = switch
    $ long "offline"
   <> help "Offline mode: create project with 'All Rights Reserved' license and without uploading to GitHub."

fileP :: Parser FilePath
fileP = strOption
    $ long "file"
   <> short 'f'
   <> metavar "FILENAME"
   <> help "Path to the toml file with configurations. If not specified '~/.summoner.toml' will be used if present"

preludePackP :: Parser Text
preludePackP = strOption
    $ long "prelude-package"
   <> metavar "PACKAGE_NAME"
   <> help "Name for the package of the custom prelude to use in the project"

preludeModP :: Parser Text
preludeModP = strOption
    $ long "prelude-module"
   <> metavar "MODULE_NAME"
   <> help "Name for the module of the custom prelude to use in the project"

cabalP :: Parser Decision
cabalP = flag Idk Yes
       $ long "cabal"
      <> help "Cabal support for the project"

stackP :: Parser Decision
stackP = flag Idk Yes
       $ long "stack"
      <> help "Stack support for the project"

----------------------------------------------------------------------------
-- Beauty util
----------------------------------------------------------------------------

-- to put custom header which doesn't cut all spaces
modifyHeader :: ParserInfo a -> ParserInfo a
modifyHeader p = p {infoHeader = stringChunk $ toString artHeader}

-- to put custom footer which doesn't cut all spaces
modifyFooter :: ParserInfo a -> ParserInfo a
modifyFooter p = p {infoFooter = stringChunk $ toString artFooter}

artHeader :: Text
artHeader = [text|
$endLine
                                                   ___
                                                 ╱  .  ╲
                                                │╲_/│   │
                                                │   │  ╱│
  ___________________________________________________-' │
 ╱                                                      │
╱   .-.                                                 │
│  ╱   ╲                                                │
│ │\_.  │ Summoner — tool for creating Haskell projects │
│\│  │ ╱│                                               │
│ `-_-' │                                              ╱
│       │_____________________________________________╱
│       │
 ╲     ╱
  `-_-'
|]

artFooter :: Text
artFooter = [text|
$endLine
              , *   +
           +      o   *             ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
            * @ ╭─╮  .      ________┃                                 ┃_______
           ╱| . │λ│ @   '   ╲       ┃   λ Haskell's summon scroll λ   ┃      ╱
         _╱ ╰─  ╰╥╯    O     ╲      ┃                                 ┃     ╱
        .─╲"╱. * ║  +        ╱      ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛     ╲
       ╱  ( ) ╲_ ║          ╱__________)                           (_________╲
       ╲ ╲(')╲__(╱
       ╱╱`)╱ `╮  ║
 `╲.  ╱╱  (   │  ║
  ╲.╲╱        │  ║
  `╰══════════╯
$endLine
|]
