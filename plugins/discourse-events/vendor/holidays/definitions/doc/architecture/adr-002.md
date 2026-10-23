# ADR 2: Year ranges syntax update

## Context

#### Original year range behavior

Starting in [v3.2.0](https://github.com/holidays/holidays/releases/tag/v3.2.0) of the ruby gem [\[1\]](#footnote-1) we have had the ability to specify year ranges for specific holidays. This allows for a holiday
to only be considered 'valid' or 'active' based on specific criteria surrounding years. The available criteria were:

* `before` - holiday only valid if it takes place on the target year or before
* `after` - holiday only valid if it takes place on the target year or after
* `limited` - holiday only valid if it takes place on at least one of an array of target years (e.g. [2002, 2004])
* `between` - holiday only valid if it takes place between an inclusive year range (e.g. 2002..2004)

This change added useful functionality and its use has since spread to multiple regions.

#### Confusion about criteria behavior

On January 24th, 2019 [an issue was opened](https://github.com/holidays/definitions/issues/117) expressing that the `before` and `after` criteria were named in a confusing manner since it was not clear whether they operated inclusively or exclusively on the target year.

As an example, the value `after: 2018` could be construed by some to mean the holiday is valid starting in 2019 and onward. In reality the current implementation is that the holiday is valid starting in 2018 itself and onward.

While this is ultimately up to individual perception it is true that the current names do not provide strong guidance on how the definition will behave.

## Decision

The [above issue](https://github.com/holidays/definitions/issues/117) also contained a proposal to make the following changes:

* Rename `before` to `until`
* Rename `after` to `from`

These names give a clearer understanding of the desired behavior as `until` and `from` are more generally understood to indicate inclusivity rather than exclusivity.

If we take the example from above and make the change then the value `from: 2018` would intend for the holiday to be valid/active starting in 2018 and onward.

#### Additional changes

While looking into the above issue I noticed two important things that will also be addressed alongside the above changes:

* The definition validator does not currently prevent users from specifying multiple selectors at a time for a `year_ranges` entry and we perform no validation that these selectors do not conflict with one another.
* The `between` key currently accepts a string representation of a Ruby range (e.g. '2008..2012'). While this was not causing any issues today we would like to remove all Ruby-specific values from our definitions so that other languages could more easily parse them.

To that end the following changes will also be made:

* Update the definition validation to only allow a single selector per `year_ranges` entry and update all definitions to match. This will result no behavior changes but will make clear the expected behavior.
* `between` will no longer accept a ruby-like range string but instead require explicit `start` and `end` keys with integer values representing a year.

## Consequences

This change will require changing multiple files and wll result in a major semantic version bump for the definitions. In addition we will also need to make a similar breaking change in all consuming apps.

There are mitigating factors, however. There are only a handful of existing definitions that use the `before`, `after`, or `between` keys and the only consuming app is the [ruby gem](https://github.com/holidays/holidays). This means our affected code is relatively small.

Additionally there was already a plan in place to perform an unrelated breaking change in the gem. This means that we can bundle these breaking changes together and minimize the amount of version churn.

## Status

Accepted.

## Footnotes

##### footnote-1

In the original `holidays` ruby library all definitions were housed in the same directory. The definitions were split into a separate repository starting with [holidays gem v5.0.0](https://github.com/holidays/holidays/blob/master/CHANGELOG.md#500).
