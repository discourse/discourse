# Ruby Holidays Gem [![Build Status](https://travis-ci.org/holidays/holidays.svg?branch=master)](https://travis-ci.org/holidays/holidays)

Functionality to deal with holidays in Ruby.

Extends Ruby's built-in Date and Time classes and supports custom holiday definition lists.

## Installation

```
gem install holidays
```

## Tested versions

This gem is tested with the following ruby versions:

  * 2.4.5
  * 2.5.3
  * 2.6.1
  * JRuby 9.2.5.0

## Semver

This gem follows [semantic versioning](http://semver.org/). The guarantee specifically covers:

 * methods in the top-most `Holidays` namespace e.g. `Holidays.<method>`
 * the [core extensions](#extending-rubys-date-and-time-classes)

Please note that we consider definition changes to be 'minor' bumps, meaning they are backwards compatible with your code but might give different holiday results!

## Time zones

Time zones are ignored.  This library assumes that all dates are within the same time zone.

## Usage

This gem offers multiple ways to check for holidays for a variety of scenarios.

#### Checking a specific date

Get all holidays on April 25, 2008 in Australia:

```
Holidays.on(Date.civil(2008, 4, 25), :au)
=> [{:name => 'ANZAC Day',...}]
```

You can check multiple regions in a single call:

```
Holidays.on(Date.civil(2008, 1, 1), :us, :fr)
=> [{:name=>"New Year's Day", :regions=>[:us],...},
    {:name=>"Jour de l'an", :regions=>[:fr],...}]
```

You can leave off 'regions' to get holidays for any region in our [definitions](https://github.com/holidays/definitions):

```
 Holidays.on(Date.civil(2007, 4, 25))
=> [{:name=>"ANZAC Day", :regions=>[:au],...},
    {:name=>"Festa della Liberazione", :regions=>[:it],...},
    {:name=>"Dia da Liberdade", :regions=>[:pt],...}
    ...
   ]
```

#### Checking a date range

Get all holidays during the month of July 2008 in Canada and the US:

```
from = Date.civil(2008,7,1)
to = Date.civil(2008,7,31)

Holidays.between(from, to, :ca, :us)
=> [{:name => 'Canada Day',...}
    {:name => 'Independence Day',...}]
```

#### Check for 'informal' holidays

You can pass the 'informal' flag to include holidays specified as informal in your results. See [here](https://github.com/holidays/definitions/blob/master/doc/SYNTAX.md#formalinformal) for information on what constitutes 'informal' vs 'formal'.

By default this flag is turned off, meaning no informal holidays will be returned.

Get Valentine's Day in the US:

```
Holidays.on(Date.new(2018, 2, 14), :us, :informal)
=> [{:name=>"Valentine's Day",...}]
```

Leaving off 'informal' will mean that Valentine's Day is not returned:

```
Holidays.on(Date.new(2018, 2, 14), :us)
=> []
```

Get informal holidays during the month of February 2008 for any region:

```
from = Date.civil(2008,2,1)
to = Date.civil(2008,2,15)

Holidays.between(from, to, :informal)
=> [{:name => 'Valentine\'s Day',...}]
```

#### Check for 'observed' holidays

You can pass the 'observed' flag to include holidays that are observed on different days than they actually occur. See [here](https://github.com/holidays/definitions/blob/master/doc/SYNTAX.md#observed) for further explanation of 'observed'.

By default this flag is turned off, meaning no observed logic will be applied.

Get holidays that are observed on Monday July 2, 2007 in British Columbia, Canada:

```
Holidays.on(Date.civil(2007, 7, 2), :ca_bc, :observed)
=> [{:name => 'Canada Day',...}]
```

Leaving off the 'observed' flag will mean that 'Canada Day' is not returned since it actually falls on Sunday July 1:

```
Holidays.on(Date.civil(2007, 7, 2), :ca_bc)
=> []
Holidays.on(Date.civil(2007, 7, 1), :ca_bc)
=> [{:name=>"Canada Day", :regions=>[:ca],...}]
```

Get all observed US Federal holidays between 2018 and 2019:

```
from = Date.civil(2018,1,1)
to = Date.civil(2019,12,31)

Holidays.between(from, to, :federalreserve, :observed)
=> [{:name => "New Year's Day"....}
    {:name => "Birthday of Martin Luther King, Jr"....}]
```

#### Check whether any holidays occur during work week

Check if there are any holidays taking place during a specified work week. 'Work week' is defined as the period of Monday through Friday of the week specified by the date.

Check whether a holiday falls during first week of the year for any region:

```
Holidays.any_holidays_during_work_week?(Date.civil(2016, 1, 1))
=> true
```

You can also pass in `informal` or `observed`:

```
# Returns true since Valentine's Day falls on a Wednesday
holidays.any_holidays_during_work_week?(date.civil(2018, 2, 14), :us, :informal)
=> true
# Returns false if you don't specify informal
irb(main):006:0> Holidays.any_holidays_during_work_week?(Date.civil(2018, 2, 14), :us)
=> false
# Returns true since Veteran's Day is observed on Monday November 12, 2018
holidays.any_holidays_during_work_week?(date.civil(2018, 11, 12), :us, :observed)
=> true
# Returns false if you don't specify observed since the actual holiday is on Sunday November 11th 2018
irb(main):005:0> Holidays.any_holidays_during_work_week?(Date.civil(2018, 11, 12), :us)
=> false
```

#### Find the next holiday(s) that will occur from a specific date

Get the next holidays occurring from February 23, 2016 for the US:

```
Holidays.next_holidays(3, [:us, :informal], Date.civil(2016, 2, 23))
=> [{:name => "St. Patrick's Day",...}, {:name => "Good Friday",...}, {:name => "Easter Sunday",...}]
```

You can specify the number of holidays to return. This method will default to `Date.today` if no date is provided.

#### Find all holidays occuring starting from a specific date to the end of the year

Get all holidays starting from February 23, 2016 to end of year in the US:

```
Holidays.year_holidays([:ca_on], Date.civil(2016, 2, 23))
=> [{:name=>"Good Friday",...},
    {name=>"Easter Sunday",...},
    {:name=>"Victoria Day",...},
    {:name=>"Canada Day",...},
    {:name=>"Civic Holiday",...},
    {:name=>"Labour Day",...},
    {:name=>"Thanksgiving",...},
    {:name=>"Remembrance Day",...},
    {:name=>"Christmas Day",...},
    {:name=>"Boxing Day",...}]
```

This method will default to `Date.today` if no date is provided.

#### Return all available regions

Return all available regions:

```
Holidays.available_regions
=> [:ar, :at, ..., :sg] # this will be a big array
```

## Loading Custom Definitions on the fly

In addition to the [provided definitions](https://github.com/holidays/definitions) you can load custom definitions file on the fly and use them immediately.

To load custom 'Company Founding' holiday on June 1st:

```
Holidays.load_custom('/home/user/holiday_definitions/custom_holidays.yaml')
Holidays.on(Date.civil(2013, 6, 1), :my_custom_region)
  => [{:name => 'Company Founding',...}]
```

Custom definition files must match the [syntax of the existing definition files](https://github.com/holidays/definitions/blob/master/doc/SYNTAX.md).

Multiple files can be loaded at the same time:

```
Holidays.load_custom('/home/user/holidays/custom_holidays1.yaml', '/home/user/holidays/custom_holidays2.yaml')
```

## Extending Ruby's Date and Time classes

### Date

To extend the 'Date' class:

```
require 'holidays/core_extensions/date'
class Date
  include Holidays::CoreExtensions::Date
end
```

Now you can check which holidays occur in Iceland on January 1, 2008:

```
d = Date.civil(2008,7,1)

d.holidays(:is)
=> [{:name => 'Nýársdagur'}...]
```

Or lookup Canada Day in different regions:

```
d = Date.civil(2008,7,1)

d.holiday?(:ca) # Canada
=> true

d.holiday?(:ca_bc) # British Columbia, Canada
=> true

d.holiday?(:fr) # France
=> false
```

Or return the new date based on the options:

```
d = Date.civil(2008,7,1)
d.change(:year => 2016, :month => 1, :day => 1)
=> #<Date: 2016-01-01 ((2457389j,0s,0n),+0s,2299161j)>
```

Or you can calculate the day of the month:

```
Date.calculate_mday(2015, 4, :first, 2)
=> 7
```

### Time

```
require 'holidays/core_extensions/time'
class Time
  include Holidays::CoreExtensions::Time
end
```

Find end of month for given date:

```
d = Date.civil(2016,8,1)
d.end_of_month
=> #<Date: 2016-08-31 ((2457632j,0s,0n),+0s,2299161j)>
```

## Caching Holiday Lookups

If you are checking holidays regularly you can cache your results for improved performance. Run this before looking up a holiday (e.g. in an initializer):

```
YEAR = 365 * 24 * 60 * 60
Holidays.cache_between(Time.now, Time.now + 2 * YEAR, :ca, :us, :observed)
```

Holidays for the regions specified within the dates specified will be pre-calculated and stored in-memory. Future lookups will be much faster.

## How to contribute

See our [contribution guidelines](doc/CONTRIBUTING.md) for information on how to help out!

## Credits and code

* Started by [@alexdunae](http://github.com/alexdunae) 2007-2012
* Maintained by [@hahahana](https://github.com/hahahana), 2013
* Maintained by [@ppeble](https://github.com/ppeble), 2014-present
* Maintained by [@ttwo32](https://github.com/ttwo32), 2016-present

Plus all of these [wonderful contributors!](https://github.com/holidays/holidays/contributors)
