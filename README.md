# 🔮 Summoner

![wizard](https://user-images.githubusercontent.com/8126674/44388234-320aac00-a55a-11e8-879d-5dca68512031.png)

[![GitHub CI](https://github.com/kowainik/summoner/workflows/CI/badge.svg)](https://github.com/kowainik/summoner/actions)

[![Hackage](https://img.shields.io/hackage/v/summoner.svg?logo=haskell)](https://hackage.haskell.org/package/summoner)
[![Stackage Lts](http://stackage.org/package/summoner/badge/lts)](http://stackage.org/lts/package/summoner)
[![Stackage Nightly](http://stackage.org/package/summoner/badge/nightly)](http://stackage.org/nightly/package/summoner)
[![MPL-2.0 license](https://img.shields.io/badge/license-MPL--2.0-blue.svg)](https://github.com/kowainik/summoner/blob/main/LICENSE)

> _So many of our dreams at first seem impossible, then they seem improbable, and
> then, when we summon the will, they soon become inevitable._
>
> Christopher Reeve

Summoner is a tool for scaffolding fully configured batteries-included production-level Haskell projects.

Do you want to create a library that is to be uploaded to Hackage/Stackage, that builds with both Cabal and Stack and supports the latest three major GHC versions?
Or are you building a production application which uses a custom prelude and has CI with  GitHub Actions or Travis Linux and AppVeyors Windows checks?
Maybe do you want to play with your idea in a single module without introducing the whole complexity of the Haskell projects?
Summoner can help you do all that with minimal effort from you - it can even upload the project to GitHub if you wish!

By the way, Summoner operates as either CLI or TUI application, so you can choose what you are more comfortable with and install only the required one.

## Structure

* [Demo](#demo)
    + [TUI demo](#tui-demo)
    + [CLI demo](#cli-demo)
    + [Examples](#examples)
* [Features](#features)
* [Get started](#get-started)
    + [Prerequisites](#prerequisites)
    + [Installation](#installation)
        + [Summon-TUI](#summon-tui)
          + [TUI: download binary](#tui-download-binary)
          + [TUI: Homebrew](#tui-homebrew)
          + [TUI: Ubuntu](#tui-ubuntu)
          + [TUI: from Hackage](#tui-from-hackage)
          + [TUI: from source](#tui-from-source)
        + [Summon-CLI](#summon-cli)
          + [CLI: download binary](#cli-download-binary)
          + [CLI: Homebrew](#cli-homebrew)
          + [CLI: Ubuntu](#cli-ubuntu)
          + [CLI: from Hackage](#cli-from-hackage)
          + [CLI: from source](#cli-from-source)
    + [Setup](#setup)
* [Usage](#usage)
    + [Command-line arguments](#command-line-arguments)
    + [File configuration](#file-configuration)
    + [TUI](#tui)
    + [CLI](#cli)
* [FAQ](#faq)
* [For Developers](#for-developers)
    + [Build](#build)
    + [Test](#test)
    + [Run](#run)
* [Acknowledgments](#acknowledgments)

## Demo

[[Back to the Table of Contents] ↑](#structure)

### TUI demo

[[Back to the Table of Contents] ↑](#structure)

[![TUI demo](https://asciinema.org/a/314375.png)](https://asciinema.org/a/314375)

### CLI demo

[[Back to the Table of Contents] ↑](#structure)

[![CLI demo](https://asciinema.org/a/314374.png)](https://asciinema.org/a/314374)

### Examples

[[Back to the Table of Contents] ↑](#structure)

You can also see complete examples in the following folder:

* [`summon-cli/examples/`: Examples of scaffolded projects](https://github.com/kowainik/summoner/tree/main/summoner-cli/examples/)

The directory contains the following examples:

* [`cabal-minimal`](https://github.com/kowainik/summoner/tree/main/summoner-cli/examples/cabal-minimal):
  Minimal Haskell project with the Cabal-only support, default
  settings and all of the integrations disabled.
* [`cabal-full`](https://github.com/kowainik/summoner/tree/main/summoner-cli/examples/cabal-full):
   Cabal-only project with all integrations enabled.
* [`stack-full`](https://github.com/kowainik/summoner/tree/main/summoner-cli/examples/stack-full):
  Stack-only project with all integrations enabled.
* [`full-batteries`](https://github.com/kowainik/summoner/tree/main/summoner-cli/examples/full-batteries):
  All batteries-included project which supports both build tools and
  shows every Summoner feature.

## Features

[[Back to the Table of Contents] ↑](#structure)

Summoner is a tool that combines predefined configurations, command-line arguments and a chosen interface.

To fully understand the power in your hands with the help of Summoner, please read this section.

Below you can see highlighted features in different categories.

### Project

[[Back to the Table of Contents] ↑](#structure)

Features related to the structure and content of the generated projects.

+ Support for Cabal and Stack build tools.
+ Ability to pick stanzas (library, executable, test-suite, benchmark).
+ Usage of [common stanza](https://vrom911.github.io/blog/common-stanzas) to reduce `.cabal` file's boilerplate.
+ Option to include an alternative prelude, if desired. The project would then
  use the [`mixins` technique](https://www.reddit.com/r/haskelltil/comments/9qa366/easy_way_to_replace_default_prelude_with_the/).
+ Whole Hackage-upload checklist support (exhaustive `.cabal` file, PVP versioning, GHC options, conventional meta files).
+ Support for multiple GHC versions, with thoughtful reflection on project meta, base versions (e.g. `base >= 4.9 && < 4.13`), etc.
+ Ability to create runnable Haskell scripts.
+ Different license support: MIT, BSD-2-Clause, BSD-3-Clause, GPL-2.0, GPL-3.0, LGPL-2.1, LGPL-3.0, AGPL-3.0, Apache-2.0, MPL-2.0, ISC, None (without file).
+ Creation of the `CHANGELOG.md` file with [PVP versioning policy](https://pvp.haskell.org).
+ Ability to include any custom files (including `.stylish-haskell.yaml`, `CONTRIBUTING.md`, `CODEOWNERS`, `FUNDING.yml` etc.).
+ Usage of the `ghc-options` field with sensible defaults.

  If `ghc-options` are not explicitly stated in the configuration file, then the following list of GHC flags is added to all stanzas:

  ```
  -Wall
  -Wcompat
  -Widentities
  -Wincomplete-uni-patterns
  -Wincomplete-record-updates
  -Wredundant-constraints
  -Wnoncanonical-monad-instances
  -fhide-source-paths           (GHC ⩾ 8.2)
  -Wmissing-export-lists        (GHC ⩾ 8.4)
  -Wpartial-fields              (GHC ⩾ 8.4)
  -Wmissing-deriving-strategies (GHC ⩾ 8.8)
  -fwrite-ide-info              (GHC ⩾ 8.8)
  -hiedir=.hie                  (GHC ⩾ 8.8)
  -Wunused-packages             (GHC ⩾ 8.10)
  ```

  Besides, the following GHC options are added to the executable, tests and benchmark stanzas:

  ```
  -threaded
  -rtsopts
  -with-rtsopts=-N
  ```

### GitHub

[[Back to the Table of Contents] ↑](#structure)

+ Initialisation of the git repository inside the project folder.
+ Initial commit creation.
+ Uploading the repository to GitHub.
+ Exhaustive `.gitignore` file.
+ Formation of the `README` file with Hackage, Stackage and CI badges.
+ Linking to the GitHub repository in the `.cabal` file.
+ Ability to include your custom GitHub meta files: `CONTRIBUTING.md`, `CODEOWNERS`, `.github/pull_request_template.md`, etc.
+ Guessing user credentials from the local `.gitconfig` file.

### CI

[[Back to the Table of Contents] ↑](#structure)

+ Generation of the `.travis.yml` file that runs build and tests on CI under Linux using
  [Dead simple Haskell Travis Settings for Cabal and Stack](https://chshersh.github.io/posts/2019-02-25-haskell-travis).
+ Generation of the `appveyor.yaml` file which runs build and tests on CI under Windows.
+ Generation of the `.github/workflows/ci.yml` file that runs build and tests on
  GitHub Actions CI under Linux using Cabal.
+ Configuration matrix on CI to build with multiple GHC versions and various build tools.
+ `-Werror` is enabled on CI not to miss any warnings.
+ Run HLint checks on CI.

### Others

[[Back to the Table of Contents] ↑](#structure)

+ Carefully collected Haskell project best practices gathered in your projects' scaffold.
+ Generate beginner-friendly default configuration using the `summon config` command.
+ Ability to create a project in the offline mode.
+ Ability to check GHC-specific versions of the corresponding `base` library
  and Stackage snapshot resolver via `summon show ghc` command.

### Project structure example

[[Back to the Table of Contents] ↑](#structure)

This is an example of the project hierarchy you can get if you are running Summoner's `new` command with all options enabled:

```
project-name/
├── app/
│   └── Main.hs
├── benchmark/
│   └── Main.hs
├── src/
│   ├── ProjectName.hs
│   └── Prelude.hs
├── test/
│   └── Spec.hs
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── project-name.cabal
├── README.md
├── Setup.hs
├── stack.yaml
├── stack-8.6.5.yaml
├── appveyor.yml
├── .git
├── .gitignore
├── .stylish-haskell.yaml
└── .travis.yml
```

## Get started

[[Back to the Table of Contents] ↑](#structure)

### Prerequisites

[[Back to the Table of Contents] ↑](#structure)

To start using Summoner make sure that you have the following tools installed on your machine:

* [`git`](https://git-scm.com) ⩾ 2.28 – to initialize the GitHub repo.
* [`gh`](https://github.com/cli/cli) – to upload the project to GitHub. You'll need to [login with `gh` first](https://cli.github.com/manual/gh_auth_login) for it to create the remote repo.
* [`curl`](https://curl.haxx.se) – to download licenses.

We also have minimal version requirements for build tools:

* [Cabal ⩾ 2.4](https://www.haskell.org/cabal/)
* [Stack ⩾ 2.1.3](http://haskellstack.org)

However, it is always recommended to use the newest versions of build tools.

### Installation

[[Back to the Table of Contents] ↑](#structure)

Summon contains two executables:

* `summon`: scaffold projects using interactive CLI mode.
* `summon-tui`: scaffold projects using TUI.

Below you can find the description of how to install each of them so you can choose the one you want.

#### Summon-TUI

[[Back to the Table of Contents] ↑](#structure)

> **NOTE:** `summon-tui` is not supported on Windows. See [this issue](https://github.com/jtdaugherty/vty/pull/1).

##### TUI: download binary

[[Back to the Table of Contents] ↑](#structure)

You can download binary directly [from GitHub releases](https://github.com/kowainik/summoner/releases).

After downloading binary, make it executable and copy it under convenient location, for example:

```shell
chmod +x summon-cli-linux
mv summon-cli-linux ~/.local/bin/summon
```

##### TUI: Homebrew

[[Back to the Table of Contents] ↑](#structure)

If you are on MacOS, you can get Summoner using Homebrew Kowainik's Tap.

You need to run the following command for that:

```shell
$ brew install kowainik/tap/summoner-tui
```

##### TUI: Ubuntu

[[Back to the Table of Contents] ↑](#structure)

If you are on Ubuntu, you can get Summoner from Kowainik's PPA.

You need to run the following commands for that:

```shell
$ sudo add-apt-repository ppa:kowainik/summoner-tui
$ sudo apt update
$ sudo apt install summoner-tui
```

##### TUI: from Hackage

[[Back to the Table of Contents] ↑](#structure)

Using `cabal`:

```shell
cabal v2-update
cabal v2-install summoner-tui
```

##### TUI: from source

[[Back to the Table of Contents] ↑](#structure)

Fetch the repo using `cabal`:

```shell
cabal get -s summoner
```

or clone the directory from GitHub:

```shell
git clone https://github.com/kowainik/summoner.git
```

Step into the directory:

```haskell
cd summoner
```

Build and install using `cabal`:

```shell
cabal v2-install summoner-tui:exe:summon-tui
```

Build and install using `stack`:

```shell
stack install summoner-tui:exe:summon-tui
```

#### Summon-CLI

[[Back to the Table of Contents] ↑](#structure)

##### CLI: download binary

[[Back to the Table of Contents] ↑](#structure)

You can download binary directly [from GitHub releases](https://github.com/kowainik/summoner/releases).

After downloading binary, make it executable and copy it under convenient location, for example:

```shell
chmod +x summon-cli-linux
mv summon-cli-linux ~/.local/bin/summon
```

##### CLI: Homebrew

[[Back to the Table of Contents] ↑](#structure)

If you are on MacOS, you can get Summoner using Homebrew Kowainik's Tap.

You need to run the following command for that:

```shell
$ brew install kowainik/tap/summoner-cli
```

##### CLI: Ubuntu

[[Back to the Table of Contents] ↑](#structure)

If you are on Ubuntu, you can get Summoner from Kowainik's PPA.

You need to run the following commands for that:

```shell
$ sudo add-apt-repository ppa:kowainik/summoner-cli
$ sudo apt update
$ sudo apt install summoner-cli
```

##### CLI: from Hackage

[[Back to the Table of Contents] ↑](#structure)

Using `cabal`:

```shell
cabal v2-update
cabal v2-install summoner
```

##### CLI: from source

[[Back to the Table of Contents] ↑](#structure)

Fetch the repo using `cabal`:

```shell
cabal get -s summoner
```

or clone the directory from GitHub:

```shell
git clone https://github.com/kowainik/summoner.git
```

Step into the directory:

```haskell
cd summoner
```

Build and install using `cabal`:

```shell
cabal v2-install summoner-cli:exe:summon
```

Build and install using `stack`:

```shell
stack install summoner:exe:summon
```

### Setup

[[Back to the Table of Contents] ↑](#structure)

You can turn on bash auto-completion by running the following command:

```shell
source <(summon --bash-completion-script `which summon`)
```

## Usage

[[Back to the Table of Contents] ↑](#structure)

To start `summon`ing projects nothing additional is required. However, to tweak your settings further, you can use additional configuration settings.
There are several options you can use to set particular configurations for new projects (in increasing order of priority):

1. Default configuration file (`~/.summoner.toml`).
2. Fields `user.login`, `user.name` and `user.email` from `~/.gitconfig`.
3. Explicitly specified configuration file by `--file FILENAME` option (used instead of the default one if specified).
4. Options that are stated by CLI arguments.
5. User input. It could be
    * **TUI** – User data specified in the window of `summon-tui`.
    * **CLI** – Interactively inputted answers during execution of the `summon` command (for the options that were not specified on previous steps).

To cut a long story short, the configuration uses [Partial Options Monoid Pattern](https://medium.com/@jonathangfischoff/the-partial-options-monoid-pattern-31914a71fc67).

### File configuration

[[Back to the Table of Contents] ↑](#structure)

Here is the list of the options that can be configured to suit your needs. If options are not specified, they are asked interactively (or some sensible defaults are used).

| Field            | Type    | Description                                                                                                                                                          |
|------------------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cabal`          | Bool    | Add Cabal support?                                                                                                                                                   |
| `stack`          | Bool    | Add Stack support?                                                                                                                                                   |
| `owner`          | Text    | GitHub login.                                                                                                                                                        |
| `fullName`       | Text    | Full name.                                                                                                                                                           |
| `email`          | Text    | E-mail address.                                                                                                                                                      |
| `license`        | License | One of: `MIT`, `BSD2`, `BSD3`, `GPL-2`, `GPL-3`, `LGPL-2.1`, `LGPL-3`, `AGPL-3`, `Apache-2.0`, `MPL-2.0`, `None`.                                                    |
| `ghcVersions`    | [GHC]   | `summoner` uses default `GHC-8.10.1`. However, additionally you can specify other versions. For each version `x.y.z` the `stack-x.y.z.yaml` will be created. Use `summon show ghc` to see all supported GHC versions. |
| `github`         | Bool    | Turn on `GitHub` integration by default?                                                                                                                             |
| `gitignore`      | [Text]  | List of files you want added to the default `.gitignore`. (Ignored if `github = false`)                                                                              |
| `noUpload`       | Bool    | Do not upload to GitHub, but create all GitHub related files if specified (Ignored if `github = false`)                                                              |
| `private`        | Bool    | Create private repository by default? (Ignored if `github = false`)                                                                                                  |
| `githubActions`  | Bool    | Turn on `GitHub Actions` integration by default?  (Currently working with `Cabal` only. Ignored if `github = false`)                                                 |
| `travis`         | Bool    | Turn on `Travis` integration by default?  (Ignored if `github = false`)                                                                                              |
| `appveyor`       | Bool    | Turn on `AppVeyor` integration by default?  (Ignored if `github = false`)                                                                                            |
| `lib`            | Bool    | Create `src` folder with simple `ProjectName.hs` file and library target?                                                                                            |
| `exe`            | Bool    | Create `app` folder with simple `Main.hs` file and executable target?                                                                                                |
| `test`           | Bool    | Create `test` folder with simple `Spec.hs` file and test target?                                                                                                     |
| `bench`          | Bool    | Create `benchmark` folder with `Main.hs` file with [`gauge`](https://hackage.haskell.org/package/gauge) library usage example?                                       |
| `extensions`     | [Text]  | List of the default extensions to add into `default-extensions` section in the `.cabal`.                                                                             |
| `ghc-options`    | [Text]  | List of the default GHC options to add into `ghc-options` section in the `.cabal`.                                                                                   |
| `files`          | Map FilePath Source  | Custom mapping of files to their sources. Represented as a list of inline tables in TOML in a format like `files = [ { path = "foo", url = "https://..." }, ... ]`. Supported file types: `url`, `local`, `raw`. |
|`[prelude]`       |         |                                                                                                                                                                      |
| `package`        | Text    | The package name of the custom prelude you'd like to use in the project (doesn't work without `module` field).                                                       |
| `module`         | Text    | The module name of the custom prelude you'd like to use in the project (doesn't work without `package` field).                                                       |

You can create default configuration using the `summon config`
command. See [the default content here](summoner-cli/test/golden/summoner-default.toml).

For a real-life example of the configuration, see [the configuration for projects of the `Kowainik` organization](https://github.com/kowainik/org/blob/main/.summoner.toml).

### Command line arguments

[[Back to the Table of Contents] ↑](#structure)

Available commands:

```
Usage:
  summon COMMAND
      Set up your own Haskell project

Available commands:
  new                      Create a new Haskell project
  script                   Create a new Haskell script
  show                     Show available licenses or ghc versions
  config                   Create default TOML configuration for summoner

Available global options:
  -h, --help               Show this help text
  -v, --version            Show summoner's version
```

#### **summon new** command:

[[Back to the Table of Contents] ↑](#structure)

```
Usage:
  summon new PROJECT_NAME [--ignore-config] [--no-upload] [--offline]
             [-f|--file FILENAME]
             [--cabal]
             [--stack]
             [--prelude-package PACKAGE_NAME]
             [--prelude-module MODULE_NAME]
             [with    [OPTIONS]]
             [without [OPTIONS]]

Available options:
  -h, --help               Show this help text
  --ignore-config          Ignore configuration file
  --no-upload              Do not upload to GitHub. Special case of the '--offline' flag.
  --offline                Offline mode: create project with 'All Rights Reserved' license
                           and without uploading to GitHub.
  --cabal                  Cabal support for the project
  --stack                  Stack support for the project
  -f, --file FILENAME      Path to the toml file with configurations. If not
                           specified '~/.summoner.toml' will be used by default
  --prelude-package PACKAGE_NAME
                           Name for the package of the custom prelude to use in
                           the project
  --prelude-module MODULE_NAME
                           Name for the module of the custom prelude to use in
                           the project

Available commands:
  with                     Specify options to enable
  without                  Specify options to disable

Available command options:
  -h, --help               Show this help text
  -g, --github             Github integration
  -p, --private            Create private GitHub repository
  -a, --actions            GitHub Actions CI integration
  -c, --travis             Travis CI integration
  -w, --app-veyor          AppVeyor CI integration
  -l, --library            Library target
  -e, --exec               Executable target
  -t, --test               Tests
  -b, --benchmark          Benchmarks
```

#### **summon script** command:

[[Back to the Table of Contents] ↑](#structure)

```
Usage:
  summon script BUILD_TOOL [-g|--ghc GHC_VERSION] [-n|--name FILE_NAME]
      Create a new Haskell script

Available options:
  -h,--help                Show this help text
  -g,--ghc GHC_VERSION     Version of the compiler to be used for script
  -n,--name FILE_NAME      Name of the script file
```

#### **summon show** command:

[[Back to the Table of Contents] ↑](#structure)

```
Usage:
  summon show COMMAND
      Show supported licenses or ghc versions

Available commands:
  ghc                      Show available ghc versions
  license                  Show available licenses
  license [LICENSE_NAME]   Show specific license text

Available options:
  -h, --help               Show this help text
```

For example, the following command preconfigures the project settings with the
custom prelude `relude`, included library, executable, test stanzas (but without
benchmarks), creates a private repository on GitHub with the GitHub Actions CI,
Travis CI and AppVeyor CI integrated.

```shell
summon new my-project with -letgcpwa without -b --prelude-package relude --prelude-module Relude
```

#### **summon config** command:

[[Back to the Table of Contents] ↑](#structure)

```
Usage: summon config [-f|--file=FILENAME]
  Create a default TOML configuration file for summoner

Available options:
  -h,--help                Show this help text
  -f,--file=FILENAME       Path to the toml file with configurations. If not
                           specified '~/.summoner.toml' will be used by default
```

This command will generate a TOML configuration file with the default settings
that can be used to scaffold future Haskell packages. It contains all
options supported by Summoner with comments and examples. Though, all
options would be turned off by default and to use them one will need
to uncomment the correspoding lines.
See [the default content here](summoner-cli/test/golden/summoner-default.toml).

Possible command usages:

```shell
summon config
summon config --file ~/.summoner-demo.toml
```

### TUI

[[Back to the Table of Contents] ↑](#structure)

#### TUI new command

[[Back to the Table of Contents] ↑](#structure)

![summon new TUI](https://user-images.githubusercontent.com/8126674/49283553-fc684e00-f4cc-11e8-8411-f173f5f19a71.png)

> **Section 1** – The main section where user inputs data or changes the configurations.

> **Section 2** – The structure of the project that is going to be created with the current configurations. This tree changes on-the-fly.

> **Section 3** – Hints, project status, or current errors in the configurations.

> **Section 4** – Useful hotkeys.

The TUI window opens with the pre-filled information received from a config file and command-line arguments. However, it's possible to change any field as per your needs.

In the screenshot you can see that you'll be given a few text fields to fill in or some checkboxes that represent boolean values of the configurations. To help you fill in the correct input, there are some ⓘ info messages in the `Status` section, which give additional details about the current field.

To help you navigate between the form fields here are the available hotkeys:

| Key                               | Action                                                                               |
|-----------------------------------|--------------------------------------------------------------------------------------|
| <kbd>Esc</kbd>                    | Abort `summoner`                                                                     |
| <kbd>Enter</kbd>                  | If input is valid go to the Confirm window                                           |
| <kbd>Tab</kbd>                    | Change the focus to the next active field                                            |
| <kbd>Shift</kbd> + <kbd>Tab</kbd> | Change the focus to the previous active field                                        |
| <kbd>Space</kbd>                  | Enable/disable current checkbox or radio button                                      |
| <kbd>Ctrl</kbd> + <kbd>d</kbd>    | Delete the input of the current text field                                           |
| <kbd>Ctrl</kbd> + <kbd>u</kbd>    | Delete the input of the current text field from the cursor position to the beginning |
| <kbd>Ctrl</kbd> + <kbd>k</kbd>    | Delete the input of the current text field from the cursor position to the end       |
| <kbd>Ctrl</kbd> + <kbd>a</kbd>    | Move the cursor to the beginning of the current input field                          |
| <kbd>Ctrl</kbd> + <kbd>e</kbd>    | Move the cursor to the end of the current input field                                |
| <kbd>Up</kbd>/<kbd>Down</kbd>     | Scroll license list when focused                                                     |

Note that the form should be valid in order to be able to go to the Confirm window. If there are some errors in the input, you could see details about these errors in the `Status` section of the form.

#### TUI script command

[[Back to the Table of Contents] ↑](#structure)

See [CLI description](#cli-script-command-) of the `summon script` command.

#### TUI show command

[[Back to the Table of Contents] ↑](#structure)

These commands display the list of supported GHC versions or Licenses. Also, when the license name is specified the window with the scrollable content of the License text is shown.

### CLI

[[Back to the Table of Contents] ↑](#structure)

#### CLI new command

[[Back to the Table of Contents] ↑](#structure)

In CLI mode of operation Summoner asks about every project setting. Most of the questions contain a default value, so you can press <kbd>Enter</kbd> to choose the default value.
If some option is specified via a configuration file or CLI arguments, then the question is skipped and the predefined value is used.

#### CLI script command

[[Back to the Table of Contents] ↑](#structure)

This command creates minimal `cabal` or `stack` script file which allows you to save some keystrokes and eliminates the need to remember magic words for scripts.

**Cabal example:** `summon script cabal -n Main.hs` generates executable file `Main.hs` with the following content:

```haskell
#!/usr/bin/env cabal
{- cabal:
build-depends:
  , base ^>= 4.13.0.0
-}

main :: IO ()
main = putStrLn "Hello, World!"
```

**Stack example:** `summon script stack -n Main.hs` generates executable file `Main.hs` with the following content:

```haskell
#!/usr/bin/env stack
{- stack
  --resolver lts-15.5
  script
  --package base
-}

main :: IO ()
main = putStrLn "Hello, World!"
```

#### CLI show command

[[Back to the Table of Contents] ↑](#structure)

These commands display the list of supported GHC versions, or Licenses. Also, when the license name is specified, the content of the License is outputted to the terminal.

## FAQ

[[Back to the Table of Contents] ↑](#structure)

> I want to use HTTPS remote for the created GitHub project, but it creates SSH one. How should I fix this?

We are using `hub` tool to create the projects at GitHub. It uses SSH so that you would get the remote links in the following format:

```
git@github.com:user/repo.git
```

We can not change or configure this behaviour, but there are several workarounds in case you _need_ to use HTTPS link for the remote.

1. Change the remote of the repository after its creation:
   ```
   git remote set-url origin https://github.com/user/repo.git
   ```
2. Change `hub` configurations globally. Simply run the following command:
   ```shell
   git config --global hub.protocol https
   ```
3. Alternatively, change `hub` configurations for a single session:
   ```
   export HUB_PROTOCOL="https"
   ```

<hr>

> Why some of the Stack checks on my TravisCI matrix are marked as "This job is
> allowed to fail"?

Due to the Stack problem of working with older versions of Cabal, the build can
fail with Stack for some older GHCs. We are adding these checks into
`allow_failures` section, as this is a known issue, and there is no need for the
whole build to fail because of that.

For more information about the issue and some workarounds from Stack developers,
see the following ticket:

  * [commersialhaskell/stack issue](https://github.com/commercialhaskell/stack/issues/4488)

## For Developers

[[Back to the Table of Contents] ↑](#structure)

If you'd like to take part in the development processes, here are a few things to keep in mind:

* Summoner is a multi-package project which has two packages inside: `summoner-cli` and `summoner-tui`. We are supporting the same functionality in both of them, so, if it's possible, you should add/change the code in both of the packages.
* Summoner uses the custom prelude [`relude`](https://github.com/kowainik/relude).
* We are using the [Kowainik style guide](https://kowainik.github.io/posts/2019-02-06-style-guide).
* To sum up, [here is the Contributing guide](https://github.com/kowainik/.github/blob/main/CONTRIBUTING.md#contributing-to-the-kowainik-repositories) we use across the repositories.
* This project is contributor-friendly, so be kind to other people working on the project.

### Dependencies

[[Back to the Table of Contents] ↑](#structure)

On Linux, to build the `summoner-tui` you'll need to have `libtinfo` installed. The easiest way to get this is from your system's package manager and is usually available as the package `libtinfo-dev`.

### Build

[[Back to the Table of Contents] ↑](#structure)

To build the project you can use the following commands:

```shell=
cabal v2-build all
```

for Cabal and

```shell=
stack build
```

for Stack.

### Test

[[Back to the Table of Contents] ↑](#structure)

Summoner uses the golden tests technique for assuring the correctness of the generated files. For this purpose, we have [the `golden` folder](https://github.com/kowainik/summoner/tree/main/summoner-cli/test/golden) with two sample projects to test against.

To actually run tests you need to run:

```shell
cabal v2-test all
```

or, if using Stack

```shell
stack test
```

### Run

[[Back to the Table of Contents] ↑](#structure)

Building Summoner with the recommended method creates two executables: `summon` and `summon-tui`. To run the compiled executable you can use the following commands:

```shell
cabal v2-exec summon -- SOME_COMMAND
cabal v2-exec summon-tui -- SOME_COMMAND
```

or, if using Stack

```shell
stack exec summon -- SOME_COMMAND
stack exec summon-tui -- SOME_COMMAND
```

## Acknowledgments

[[Back to the Table of Contents] ↑](#structure)

This project was inspired by [Aelve/new-hs](https://github.com/aelve/new-hs#readme),
which is the tool with the same goal but it's only for creating cabal projects.

Icons made by [Nikita Golubev](https://www.flaticon.com/authors/nikita-golubev)
from [Flaticon](https://www.flaticon.com/) is licensed by
[CC 3.0 BY](http://creativecommons.org/licenses/by/3.0/).
