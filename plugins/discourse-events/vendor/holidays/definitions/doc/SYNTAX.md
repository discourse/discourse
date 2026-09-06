# Holiday Definition Syntax

The definition syntax is a custom format developed over the life of this project. All holidays are defined in these YAML files. These definition files have three main top-level properties:

* `months` - this is the meat! All definitions for months 1-12 are defined here
* `methods` - this contains any custom logic that your definitions require
* `tests` - this contains the tests for your definitions

The `months` property is required. The two other properties are not strictly required but are almost always used.

In fact, if you leave out `tests` your PR will probably not be accepted unless there is a very, very good reason for leaving it out.

## Key Words

There are some terms that you should be familiar with before we dive into each section:

#### `region`

A region is a symbol that denotes the geographic or cultural region for that holiday. In general these symbols will be the [ISO 3166](https://en.wikipedia.org/wiki/ISO_3166) code for a country or region.

##### Sub-region

We also have a concept of a `sub-region`. These regions exist inside of a 'parent' region and inherit the parent's holidays. We use an underscore to specify a subregion.

Examples:

* `:us_dc` for Washington, D.C in `:us`
* `:ca_bc` for British Columbia in `:ca`

Some sub-regions do not have a matching ISO 3116 entry. In these cases we attempt to choose symbols that are reasonably clear.

##### Non-standard regions

Before version v1.1.0 of the original ruby gem the compliance with ISO 3166 was not as strict. There might be cases where an existing region symbol does not match the ISO standard.

Non-standard regions (e.g. `ecbtarget`, `federalreserve`, etc) must be all one word, just like a normal region. They must not use underscores or hyphens.

#### `formal`/`informal`

We consider `formal` dates as government-defined holidays. These could be the kinds of holidays where everyone stays home from work or perhaps are bank holidays but it is *not required* for a holiday to have these features to be considered formal.

`Informal` holidays are holidays that everyone knows about but aren't enshrined in law. For example, Valentine's Day in the US is considered an informal holiday.

We recognize that these definitions can be highly subjective. If you disagree with the current status of a holiday please open an issue so we can discuss it.

#### `observed`

There are certain holidays that can be legally observed on different days than they occur. For example, if a holiday falls on a Saturday but it is legally observed on the following Monday then you can define it as `observed` on the Monday. Please see the section below for more details and examples.

## Months

Holidays are grouped by month from 1 through 12.  Each entry within a month can have several properties depending on the behavior of the holiday. Each section below lays out the various different ways you can define your holiday.

The two required properties are:

* `name` - The name of the holiday
* `regions` - One or more region codes (targeted to match [ISO 3166](https://en.wikipedia.org/wiki/ISO_3166))

### Dates defined by a fixed date (e.g. January 1st)

* `mday` - A non-negative integer representing day of the month (1 through 31).

For example, the following holiday is on the first of January and available in the `:ca`, `:us` and `:au` regions:

```yaml
1:
- name: New Year's Day
  regions: [ca, us, au]
  mday: 1
```

### Dates defined by a week number (e.g. first Monday of a month)

* `wday` - A non-negative integer representing day of the week (0 = Sunday through 6 = Saturday).
* `week` - A non-negative integer representing week number (1 = first week, 3 = third week, -1 = last week),

For example, the following holiday is on the first Monday of September and available in the `:ca` region:

```yaml
9:
- name: Labour Day
  regions: [ca]
  week: 1
  wday: 1
```

### 'Formal' vs 'Informal' types

As mentioned above you can specify two different types. By default a holiday is considered 'formal'. By adding a `type: informal` to a definition you will mark it as 'informal' and it will only show up if the user specifically asks for it.

Example:

```yaml
9:
- name: Some Holiday
  regions: [fr]
  mday: 1
  type: informal
```

If a user submits:

```ruby
Holidays.on(Date.civil(2016, 9, 1), :fr)
```

Then they will not see the holiday. However, if they submit:

```ruby
Holidays.on(Date.civil(2016, 9, 1), :fr, :informal)
```

Then the holiday will be returned. This is especially useful for holidays like "Valentine's Day" in the USA, where it is commonly recognized as a holiday in society but not as a day that is celebrated by taking the day off.

### Year ranges

Certain holidays in various countries are only in effect during specific year ranges. A few examples of this are:

* A new holiday that starts in 2017 and continues into the future
* An existing holiday that has been cancelled so that the final year in effect is 2019
* A historical holiday that was only in effect from 2002 through 2006

To address these kinds of scenarios we have the ability to specify 'year ranges' for individual holiday definitions. There are a total of four selectors that can be specified. All must be specified in terms of 'years'. Only one selector can be used at a time.

#### `until`

The 'until' selector will only return a match if the supplied date takes place in the same year as the holiday or earlier.

A single integer representing a year *must* be supplied. An array of values will result in an error.

Example:

```yaml
7:
  name: 振替休日
  regions: [jp]
  mday: 1
  year_ranges:
    until: 2002
```

This will return successfully since the date is before 2002:

```ruby
Holidays.on(Date.civil(2000, 7, 1), :jp)
```

This will also return successfully since the date takes place on 2002 exactly:

```ruby
Holidays.on(Date.civil(2002, 7, 1), :jp)
```

This will not since the date is after 2002:

```ruby
Holidays.on(Date.civil(2016, 7, 1), :jp)
```

#### `from`

The 'from' selector will only return a match if the supplied date takes place in the same year as the holiday or later.

A single integer representing a year *must* be supplied. An array of values will result in an error.

Example:

```yaml
7:
  name: 振替休日
  regions: [jp]
  mday: 1
  year_ranges:
    from: 2002
```

This will return successfully since the date is after 2002:

```ruby
Holidays.on(Date.civil(2016, 7, 1), :jp)
```

This will also return successfully since the date takes place on 2002 exactly:

```ruby
Holidays.on(Date.civil(2002, 7, 1), :jp)
```

This will not since the date is before 2002:

```ruby
Holidays.on(Date.civil(2000, 7, 1), :jp)
```

#### `limited`

The 'limited' selector will only find a match if the supplied date takes place during
one of the specified years. Multiple years can be specified.

An array of integers representing years *must* be supplied. Providing anything other than an array of integers will result in an error.

Please note that this is *not* a range! This is an array of specific years during which the holiday is active. If you need a year range please see the `between` selector below.

Example:

```yaml
7:
  name: 振替休日
  regions: [jp]
  mday: 1
  year_ranges:
    limited: [2002,2004]
```

Both of these examples will return successfully since the dates takes place in 2002 and 2004 exactly:

```ruby
Holidays.on(Date.civil(2002, 7, 1), :jp)
Holidays.on(Date.civil(2004, 7, 1), :jp)
```

Neither of these will return since the dates takes place in outside of 2002 and 2004:

```ruby
Holidays.on(Date.civil(2000, 7, 1), :jp)
Holidays.on(Date.civil(2003, 7, 1), :jp)
```

#### `between`

The 'between' selector will only find a match if the supplied date takes place during the specified _inclusive_ range of years.

To use this selector you *must* provide both a `start` and `end` key. Both values must be integers representing years.

Example:

```yaml
7:
  name: 振替休日
  regions: [jp]
  mday: 1
  year_ranges:
    between:
      start: 1996
      end: 2002
```

These examples will return successfully since they take place within the specified range:

```ruby
Holidays.on(Date.civil(1996, 7, 1), :jp)
Holidays.on(Date.civil(2000, 7, 1), :jp)
Holidays.on(Date.civil(2002, 7, 1), :jp)
```

These will not since both are outside of the specified start/end range:

```ruby
Holidays.on(Date.civil(2003, 7, 1), :jp)
Holidays.on(Date.civil(1995, 7, 1), :jp)
```

## Methods

Sometimes you need to perform a complex calculation to determine a holiday. To facilitate this we allow for users to specify custom methods to calculate a date. These should be placed under the `methods` property. Methods named in this way can then be referenced by entries in the `months` property.

#### Important note

One thing to note is that these methods are _language specific_ at this time, meaning we would have one for ruby, one for golang, etc. Coming up with a standardized way to represent the logic in the custom-written methods proved to be very difficult. This is a punt until we can come up with a better solution.

Please feel free to only add the custom method source in the language that you choose. It will be up to downstream maintainers to ensure that their language has an implementation. So if you only want to add it in ruby please just do that!

### Method Example

Canada celebrates Victoria Day, which falls on the Monday on or before May 24. Under the `methods` property we would create a custom method for ruby that returns a Date object:

```yaml
methods:
  ca_victoria_day:
    arguments: year
    ruby: |
      date = Date.civil(year, 5, 24)
      if date.wday > 1
        date -= (date.wday - 1)
      elsif date.wday == 0
        date -= 6
      end

      date
```

This could then be used in a `months` entry:

```yaml
5:
- name: Victoria Day
  regions: [ca]
  function: ca_victoria_day(year)
```

### Available arguments

You may only specify the following values for arguments into a custom method: `date`, `year`, `month`, `day`, `region`

Correct example:

```yaml
1:
- name: Custom Method
  regions: [us]
  function: custom_method(year, month, day)
```

The following will return an error since `week` is not a recognized argument:

```yaml
1:
- name: Custom Method
  regions: [us]
  function: custom_method(week)
```

#### Whaa? Why do you restrict what I can pass in?

This was done as an attempt to make it easier for the downstream projects to parse and use the custom methods. They have to be able to pass in the required data so we limit it to make that process easier.

We can add to this list if your custom logic needs something else! Open an issue with your use case and we can discuss it.

### Methods without a fixed month

If a holiday does not have a fixed month (e.g. Easter) it should go in the '0' month:

```yaml
0:
- name: Easter Monday
  regions: [ca]
  function: easter(year)
```

### Pre-existing methods

There are pre-existing methods for highly-used calculations. You can reference these methods in your definitions as you would a custom method that you have written:

* `easter(year)` - calculates Easter via Gregorian calendar for a given year
* `orthodox_easter(year)` - calculates Easter via Julian calendar for a given year
* `to_monday_if_sunday(date)` - returns date of the following Monday if the 'date' argument falls on a Sunday
* `to_monday_if_weekend(date)` - returns date of the following Monday if the 'date' argument falls on a weekend (Saturday or Sunday)
* `to_weekday_if_boxing_weekend(date)` - returns nearest following weekday if the 'date' argument falls on Boxing Day
* `to_weekday_if_boxing_weekend_from_year(year)` - calculates nearest weekday following Boxing weekend for given year
* `to_weekday_if_weekend(date)` - returns nearest weekday (Monday or Friday) if 'date' argument falls on a weekend (Saturday or Sunday)

*Protip*: you can use the `easter` methods to calculate all of the dates that are based around Easter. It's especially useful to use since the Easter calculation is complex. For example, 'Good Friday' in the US is 2 days before Easter. Therefore you could do the following:

```
0:
- name: Good Friday
  regions: [us]
  function: easter(year)
  function_modifier: -2
  type: informal
```

Use the `function_modifier` property, which can be positive or negative, to modify the result of the function.

### Calculating observed dates

Users can specify that this gem only return holidays on their 'observed' day. This can be especially useful if they are using this gem for business-related logic. If you wish for your definitions to allow for this then you can add the `observed` property to your entry. This requires a method to help calculate the observed day.

Several built-in methods are available for holidays that are observed on varying dates.

For example, for a holiday that is observed on Monday if it falls on a weekend you could write:

```
7:
- name: Canada Day
  regions: [ca]
  mday: 1
  observed: to_monday_if_weekend(date)
```

If a user does not specify `observed` in the options then 7/1 will be the date found for 'Canada Day', regardless of whether it falls on a Saturday or Sunday. If a user specifies 'observed' then it will show as the following Monday if the date falls on a Saturday or Sunday.

## Tests

All definition files should have tests included. At this time we do not enforce any rules on coverage or numbers of tests. However, in general, PRs will not be accepted if they are devoid of tests that cover the changes in question.

The format is a straightforward 'given/expect'. Here is a simple example:

```yaml
- given:
    date: '2018-1-1'
    regions: ["ex"]
  expect:
    name: "Example Holiday"
```

Here are format details:

* given (required)
  * date (required) - all dates must be in 'YYYY-MM-DD' format. Either a single day or an array of dates can be used.
  * regions (required) - an array of strings (NOT symbols). Multiple regions can be passed. Even a single region must be in an array.
  * options (optional) - an array of options to use for this test. Can be either 'informal' or 'observed'. Must be an array of strings, e.g. `['informal', 'observed']`
* expect (required)
  * name (optional) - the name of the holiday you are expecting. Must be a string.
  * holiday (optional) - a boolean indicating whether the given values result in a holiday. Defaults to 'true' if not present. Must be true or false.

One or the other of the `expect` keys is required. If you do not specify a `name` then you should set `holiday: false`.

#### Test Examples

First example shows multiple dates, multiple regions, additional options, and an expectation that the result will be the named holiday:

```yaml
- given:
    date: ['2018-1-1', '2019-3-5']
    regions: ["ex", "ex2", "ex3"]
    options: ["informal"]
  expect:
    name: "Example Holiday"
```

Second example shows multiple dates, a single region, multiple options, and an expectation that the given values will *not* result in a found holiday. No name is required because...no holiday is expected to be found.

```yaml
- given:
    date: ['2022-12-1', '2019-4-1', '2046-8-8]
    regions: ["ex"]
    options: ["informal", "observed"]
  expect:
    holiday: false
```

These tests will be picked up by the `generate` process in the client repositories and written into actual tests in the given language that are run when a user executes the test suite.

Please please please include tests. Your PR won't be accepted if tests are not included with your changes.
