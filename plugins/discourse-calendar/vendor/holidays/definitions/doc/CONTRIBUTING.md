# How to contribute

In this repository we have all of the definitions that are used in holiday calcuations. We rely on users around the world to help keep our definitions accurate and up to date.

## Code of Conduct

Please read our [Code of Conduct](https://github.com/holidays/holidays/blob/master/CODE_OF_CONDUCT.md) before contributing. Everyone interacting with this project (or associated projects) is expected to abide by its terms.

## Definition Updates

Our definitions are written in YAML. You can find a complete guide to our format in the [syntax docs](SYNTAX.md). We take the YAML definitions and generate final definition files in the various projects that are loaded at runtime for fast calculations.

Here are the steps to take once you have a good idea on what you want to change:

* Fork this repository
* Edit desired definition YAML file(s). If you are adding a new region be sure to update `index.yaml` as well
* Run `make validate` to ensure that all updates match our definition format
* Open a PR with your changes

Including documentation with your updates is very much appreciated. A simple Wikipedia entry or government link in the comments alongside your changes would be perfect.

Lastly, note that there are many 'meta' regions. For example, there are regions for Europe, Scandinavia, and North America. If your new region(s) falls into these areas consider adding them. You can find these 'meta' regions in `definitions/index.yaml`.

Don't worry about versioning, we'll handle it on our end.

*Tests are required for new definitions*.

## Definition Validation

We maintain a `make validate` command to ensure that all YAML definitions match our internal specifications. This is to make working with this repository as independent as possible from the other repositories (like the existing ruby repository). If `make validate` passes then we ensure that anything consuming these files will receive 'correct' formats.

If you run into any weird `make validate` errors please open an issue or PR and highlight to what you are seeing. The validation code is brand-new and might have issues. Maintainers will respond quickly to any open problems.

If you would like to add to, update, or otherwise fix any of our specs then please fork and submit a PR like you would any other change. Please note that we require 100% test coverage. Your builds will not pass if you fall below 100%.
