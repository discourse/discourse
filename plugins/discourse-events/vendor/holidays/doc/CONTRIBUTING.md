# How to contribute

There are multiple ways to help! We rely on users around the world to help keep our definitions accurate and up to date. In addition, pull requests to address bugs or implement new features are always welcome.

## Code of Conduct

Please read our [Code of Conduct](../CODE_OF_CONDUCT.md) before contributing. Everyone interacting with this project (or associated projects) is expected to abide by its terms.

## General note

The definitions for this project are housed in a submodule. When pulling this repo please make sure to run `git clone --recursive git@github.com/holidays/holidays`
or, if you forgot to do so, run `make update-defs` so that all of the submodule data is pulled correctly.

## For definition updates

Our definitions are written in YAML. They are housed in a [separate repository](https://github.com/holidays/definitions) so that they can be used by tools written in other languages. You can find a complete guide to our format in the [definitions SYNTAX guide](https://github.com/holidays/definitions/blob/master/doc/SYNTAX.md).

In this ruby project we take the YAML definitions and generate final ruby classes that are loaded at runtime for fast calculations.

Once you have a good idea on what you want to change, please see the [CONTRIBUTING guide](https://github.com/holidays/definitions/blob/master/doc/CONTRIBUTING.md) in the `definitions` repository.

The idea is that if the validation passes on the other repo then you shouldn't have to worry about generating and testing here. We'll see how that goes!

Once that PR is accepted the maintainers of this project will be responsible for generating the updated definitions here and releasing a new gem. Don't worry about versioning, we'll take care of it!

#### Testing out your definitions locally

As mentioned above we use a git submodule for the definitions. Sometimes you might want to manually test out how this ruby project will behave with your changes. To facilitate that we provide some commands for pointing the definitions submodule to your fork/branch.

To point at your fork/branch:

```sh
make clean-defs
BRANCH=<branch-name> USER=<user> make point-to-defs-branch
```

Example:

```sh
make clean-defs
BRANCH=issue-24 USER=ppeble make point-to-defs-branch
```

This will pull everything down for the latest commit on that fork/branch. When you are done testing and want to point back at the master definitions:

```sh
make clean-defs
make point-to-defs-master
```

## For non-definition functionality

* Fork this repository
* Make your changes. Don't forget to run `make test` to execute the test suite!
* Create a PR pointing back to `master`

Don't worry about versioning, we'll handle it on our end.

*Tests are required*. If your PR results in lower test coverage then it will not be accepted.

## Local development helpers

We have included a few handy tasks to help you troubleshoot and test:

* `make test` - runs the entire suite
* `bundle exec ruby <test-file-to-run>` - runs just the tests in the specified file
* `REGION=<region> make test-region` - runs the tests for just that region
* `make console` - launches an IRB session with the 'holidays' gem loaded for quick testing
* `make update-defs` - runs the appropriate git submodule commands to pull the latest definitions
* `make clean-defs` - removes the definitions submodule, useful for switching between a fork and the main definitions repository
* `BRANCH=<branch> USER=<user> make point-to-defs-branch` - updates your definitions submodule to point at a fork/branch
* `make point-to-defs-master` - updates your definitions submodule to point back at the `holidays/definitions` repo and master branch
