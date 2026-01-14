# Maintainers guide

This document outlines the process of releasing an update to the `holidays` gem. This update could
include any (or a combination of) the following:

* definition updates from the [definitions](https://github.com/holidays/definitions) repository
* bug fixes
* additional functionality

### semver

This gem operates under the rules of [semver](http://semver.org/). The decisions on what constitutes a major,
minor, or patch version update fall on the maintainer. If in doubt, follow these rules:

* Will this change mean that users will be REQUIRED to make a code change? If so then it is a major version bump. This includes dropping supported versions of ruby!
* Will this change mean that users might see a definition/behavior change but won't need to modify their own code? If so then it is as minor version bump
* Will this change mean that a bug, either in code or definitions, will be fixed? If so then it is a patch version bump

*@ppeble editor note*: I am pretty aggressive when it comes to version bumps! If the slightest functionality has changed then
I consider it a minor version bump, if ANY consumer code has to change then I consider it a major version bump. I don't care
if we get up to version 250, the version number doesn't matter. Communicating the effort required in updating is what matters!

### Who this document is for

This document is for maintainers that have merge access to this repository. These maintainers may or may not have access to the upstream
[definitions](https://github.com/holidays/definitions) repository.

Please note that a core contributor must provide the relevant Github access so that you can perform merges. If you have any issues
please contact the [core members](https://github.com/orgs/holidays/teams/core/members) for assistance.

### Setup

This guide assumes that you have forked the repository in Github. If you require assistance in this please contact the core members listed above.

You will need upload access to rubygems.org in order to publish gems. Contact a [core member](https://github.com/orgs/holidays/teams/core/members) for assistance.

### Release Overview

A release could contain one or more of the following:

* definition updates - these are rule updates pulled from https://github.com/holidays/definitions. These changes are not
language specific and will most likely require local regeneration of compiled rules.
* functionality additions - this is new functionality in this repository that uses the existing definitions
* bug fixes - these are bug fixes in this repository

It is up to the maintainer to determine what needs to be updated. We will attempt to outline the various scenarios in the
sections below.

### Release flow

* Does this update require definition updates? If YES, then:
  * Pull the latest `master` version of this ruby repository and run `make update-defs`. This will grab the latest version from the [definitions](https://github.com/holidays/definitions) repository. Run `git diff` to verify that the version of the submodule for the definitions matches the latest commit in the [definitions](https://github.com/holidays/definitions) repo.
  * Run the `make generate` command. This will 'recompile' the ruby sources with the latest definitions.
  * Run `make test` and ensure that all of the tests pass. If any tests fail then do *not* merge and contact a [core member](https://github.com/orgs/holidays/teams/core/members) for assistance.
  * If all of the tests pass, update the `lib/holidays/version.rb` file to the new version. Reference the above [semver](http://semver.org/) rules for how to update versions.
  * Make a branch on your fork and update the [CHANGELOG](../CHANGELOG.md) to reflect the latest changes. You do not need to put in all of the definition changes in this update, you can simply reference the other repository. See other entries in the CHANGELOG for examples.
  * Open a PR against the new branch and merge it (another maintainer will need to review before you can merge)
  * Once the branch is merged, pull down the latest master from Github and run `make build`. This will generate a new `gem` file with the new version. The new version number is pulled from the above `version.rb` update.
  * If the build was successful then you can run the following to push up to rubygems.org: `GEM=<gem> make push`. Example: `GEM=holidays-6.2.0.gem make push`
* Does this update require functionality additions or bug fixes? If YES, then:
  * Run `make test` and ensure that all of the tests pass. If any tests fail then do *not* merge and contact a [core member](https://github.com/orgs/holidays/teams/core/members) for assistance.
  * If all of the tests pass, make a branch on your fork and update the [CHANGELOG](../CHANGELOG.md) to reflect the latest changes.
  * Update the `lib/holidays/version.rb` file to the new version. Reference the above [semver](http://semver.org/) rules for how to update versions.
  * Open a PR against the new branch and merge it (another maintainer will need to review before you can merge)
  * Once the branch is merged, pull down the latest master from Github and run `make build`. This will generate a new `gem` file with the new version. The new version number is pulled from the above `version.rb` update.
  * If the build was successful then you can run the following to push up to rubygems.org: `GEM=<gem> make push`. Example: `GEM=holidays-6.2.0.gem make push`

You are done! The latest version should be uploaded to rubygems.org. You can go to view the [holidays page](https://rubygems.org/gems/holidays) to verify that the latest version is available.

It is totally acceptable to do both functionality AND definition updates in a single release. Simply combine both sets of rules into a single branch for your update.

### Troubleshooting

The biggest hurdle in this repository is that [upstream definition](https://github.com/holidays/definitions) changes will
result in failures in existing tests and it will not be because of ruby issues but rather upstream issues. If you notice any test failures
that seem to be specific to certain regions then look at recent changes in that other repository. If there were changes there then the odds
are that there are issues in the definition-specific tests. This is most likely not a language (i.e. ruby) specific issue.

It is a known issue that the definitions do not have a good set of self-tests to ensure that they are internally consistent. This means that a failure in this
repository could NOT be related to ruby specifically. It could be that the 'tests' specified in in the YAML files are incorrect! If you encounter errors here
make sure that you don't assume that it is just a ruby error that is causing the issues!
