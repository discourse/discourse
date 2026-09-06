# Ruby Holidays Gem CHANGELOG

## 8.4.1

* Fix jp holidays from 2022. 

## 8.4.0

* Update submodule definitions. 
* Thanks to contributors!!


## 8.3.0

* Update submodule definitions. 
* Remove test about feb 29 on non leap year.
* Thanks to contributors!!

## 8.2.0

* Update submodule definitions. Thanks to contributors!!

## 8.1.0

* Update submodule definitions, so that the newest holidays from the definition
  gem are represent here.

## 8.0.0

* Remove support for ruby 2.2 and ruby 2.3.
* Add support for latest ruby 2.6
* Update to [v5.0.1 definitions](https://github.com/holidays/definitions/releases/tag/v5.0.1). Please see the changelog for the definition details.

## 7.1.0

* Update to [v4.1.0 definitions](https://github.com/holidays/definitions/releases/tag/v4.1.0). Please see the changelog for the definition details.

## 7.0.0

Major semver bump due to the major version change in the [definitions](https://github.com/holidays/definitions/blob/master/CHANGELOG.md#400). Several non ISO regions have been modified in order to provide more clarity for parent and sub-regions.

Affected regions:

* `ecb_target` region changed to `ecbtarget`
* `federal_reserve` region changed to `federalreserve`
* `federalreservebanks` region changed to `federalreservebanks`
* `north_america_informal` region changed to `northamericainformal`
* `united_nations` region changed to `unitednations`
* `north_america` region changed to `northamerica`
* `south_america` region changed to `southamerica`

Please see the [definitions v4.0.0 CHANGELOG](https://github.com/holidays/definitions/blob/master/CHANGELOG.md#400) for the full change list.

## 6.6.1

* Fixes `any_holidays_during_work_week?` so that it actually does what it says it does [issue-264](https://github.com/holidays/holidays/issues/264)

## 6.6.0

* Update to [v3.0.0 definitions](https://github.com/holidays/definitions/releases/tag/v3.0.0). This required updates to the custom method parser but no behavior changes.
* Remove unused `simplecov-rcov` from gemspec dev dependencies
* Fix parent region loading bug [PR](https://github.com/holidays/holidays/pull/320) (thanks to chadrschroeder)
* Fix `ruby-head` build caused by new 'endless range' feature in ruby 2.6.0 [PR](https://github.com/holidays/holidays/pull/321)
* Refactor definition search logic for improved readability [PR](https://github.com/holidays/holidays/pull/318) (thanks to https://github.com/guizma)
* Reorganize most documentation into the `docs/` directory
* Fix list of covered rubies in README

## 6.5.0

* Update to [v2.5.2 definitions](https://github.com/holidays/definitions/releases/tag/v2.5.2). Please see the changelog for the definition details.
* Fix permissions on `bin` executables (thanks to github.com/JuanitoFatas)

## 6.4.0

* Update to [v2.4.0 definitions](https://github.com/holidays/definitions/releases/tag/v2.4.0). Please see the changelog for the definition details.

## 6.3.0

* Update to [v2.3.0 definitions](https://github.com/holidays/definitions/releases/tag/v2.3.0). Please see the changelog for the definition details.

## 6.2.0

* Update to [v2.2.1 definitions](https://github.com/holidays/definitions/releases/tag/v2.2.1). Please see the changelog for the definition details.
* README update to add `:federal_reserve` examples (thanks to https://github.com/aahmad)

## 6.1.0

* Update to [v2.1.1 definitions](https://github.com/holidays/definitions/releases/tag/v2.1.1). Please see the changelog for
  the definitions for details.

## 6.0.0

* Remove support for ruby 2.1.0 since it is [no longer officially supported](https://www.ruby-lang.org/en/news/2017/04/01/support-of-ruby-2-1-has-ended/). This is the cause of the major
  version bump.
* Update to [v2.0.0 definitions](https://github.com/holidays/definitions/releases/tag/v2.0.0). This changes the format
  of definition tests and requires the other changes.
* Rewrite test generation logic to consume new YAML format.

To be crystal clear: this version should not behave differently in terms of holiday results than v5.7.0 of the gem. Any
differences are a bug that should be addressed.

## 5.7.0

* Update to [v1.7.1 definitions](https://github.com/holidays/definitions/releases/tag/v1.7.1). Please see the
  definitions repository for the list of changes.
* Remove 'coveralls'. We never looked at the reports. We will we simplecov to enforce test coverage. It will
  start off being set to require 99% and above.

## 5.6.0

* Update to v1.6.1 definitions, which includes updates for the `:ca` region (and subregions)

## 5.5.1

* Update to v1.5.1 definitions, which includes bugfix in `fedex` custom method

## 5.5.0

* Fix [#251](https://github.com/holidays/holidays/issues/251): `load_custom` would override all other definitions
* Fix [#266](https://github.com/holidays/holidays/issues/266): `:any` does not return expected results
* Fix [#265](https://github.com/holidays/holidays/issues/265): Jersey/je not loaded as expected when pulling `:gb`
* Add lunar date calculations, which are used in `:kr` and `:vi` definitions (thanks to https://github.com/jonathanpike)
* Improve cache performance (thanks to https://github.com/mzruya)
* Remove incorrect comments in definition generation (thanks to https://github.com/morrme)
* Fix bug related to definition functions inadvertently affecting subsequent date calculations
* Point to latest version (1.5.0) of definitions, which includes:
  * Add Vietnamese holidays
  * Updates Australian holidays
  * Updates Korean holidays to use native language and fancy lunar date calculations
  * Fix NYSE definitions to correctly calculate observed "New Year's Day"

## 5.4.0

* Add support for ruby 2.4.0 (added it to the required tests in Travis CI)
* Fix issue [#250](https://github.com/holidays/holidays/issues/250), which was that subregions were 'lost' if there was more than one underscore in it (thanks to https://github.com/chinito)
* Fix caching when using Date extensions (thanks to https://github.com/alexgerstein)
* Remove unused weekend date calculator method (thanks to https://github.com/ttwo32)
* Use FULL_DEFINITIONS_PATH when loading definitions to avoid NameErrors when iterating whole LOAD_PATH (thanks to https://github.com/burke)
* Point to latest version (1.3.0) of definitions, which includes:
  * Add Tunisian (tn) holidays (thanks to https://github.com/achr3f)
  * Corrects various Australian holidays
  * Update certain German regions for accuracy
  * Change 'yk' to 'yt'

## 5.3.0

* Fix `ca` province/territory codes for 'Newfoundland and Labrador' and 'Yukon' (thanks to https://github.com/slucaskim)

## 5.2.1

* Fix caching (i.e. calls to `cache_between`) to...you know, actually cache correctly and give
  performance improvements. Thanks to https://github.com/AnotherJoSmith for the fix!

## 5.2.0

* Point to latest (v1.2.0 of definitions)
  * updates `jp` defs to fix 'Foundation Day' name
  * Fix `ca` defs for observed holidays
  * Update `au` defs to have Christmas and Boxing Day for all of Australia instead of just individual territories
  * Update `ie` defs to consolidate St Stephen's Day to use common method instead of custom method

## 5.1.0

* Add `load_all` method to `Holidays` namespace to preload all definitions (i.e. no lazy loading)
* Fix issue-234: correctly load available regions so there is no error on `Holidays.available_regions` call

## 5.0.0

* Remove support for jruby 1.7 (this is the main reason for the major semver bump)
* Remove support for ruby 2.0 (since it is no longer being supported by the core ruby team)
* Add back the lazy loading of regions (this was removed in the 4.0.0 bump) instead of loading upon require (this should have
  no outward repercussions for users)
* Move definitions into their own repository and add as submodule. This will allow for more flexibility for tools written
  in other languages.
* Rename `DateCalculatorFactory` to `Factory::DateCalculator`

## 4.7.0

* Fix issue-225 (`LocalJumpError` for certain `jp` definition combinations) (https://github.com/ttwo32)
* Add Korean Lunar holidays (https://github.com/jonathanpike)

## 4.6.0

* Add holidays for 'Luxembourg' (https://github.com/dunyakirkali)

## 4.5.0

* Add `Holidays.year_holidays` method to obtain all holidays occuring from date to end of year, inclusively (thanks to https://github.com/jonathanpike)

## 4.4.0

* Add Peruvian holiday definitions (https://github.com/Xosmond)

## 4.3.0

* Update Portuguese holidays to restore 4 holidays (https://github.com/ruippeixotog)

## 4.2.0

* BUGFIX Issue-194: correctly calculate `next_holidays` if next holiday is far in the future
* Give dutch holidays their proper names (https://github.com/Qqwy)

## 4.1.0

* Issue-161: correctly report St Andrews Day as informal 2006 and earlier in `gb_sct`
* Issue-169: set correct years of observance for Family Day in various `ca` provinces
* Issue-163: Add `next_holidays` method. See README for usage (https://github.com/ttwo32)

## 4.0.0

Major refactor with breaking changes! Sorry for the wall of text but there is a lot of info here.

* Fixes issue 144 (loading custom defs with methods). This was the refactor catalyst. Changes highlights include:
  - Allow for custom methods added via the `load_custom` method to be used immediately as expected
  - Consolidate and clarify custom method parsing and validation
  - Change nearly every definition to use new 'custom method' YAML format. See `definitions/README.md` for more info.
  - Remove `require` functionality when loading new definitions, instead using in-memory repositories. See below for info.
  - Now loads all generated definitions when `require 'holidays'` is called. See below for performance info.
* Add `rake console` command for easier local testing
* Remove or rename many public methods that were never intended for public use:
  - Remove following date calculation helper methods (definitions must now directly call factory):
    - `easter`
    - `orthodox_easter`
    - `orthodox_easter_julian`
    - `to_monday_if_sunday`
    - `to_monday_if_weekend`
    - `to_weekday_if_boxing_weekend`
    - `to_weekday_if_boxing_weekend_from_year`
    - `to_weekday_if_weekend`
    - `calculate_day_of_month`
  - Remove `available` method. This was only intended for internal use
  - Remove `parse_definition_files_and_return_source`. This was only intended for internal use
  - Remove `load_all` method. This was only intended for internal use
  - Rename `regions` to `available_regions` for clarity
  - Rename `full_week?` to `any_holidays_during_work_week?` for clarity
* Following methods now constitute the 'public API' of this gem:
  -  `on`
  -  `any_holidays_during_work_week?` (renamed method, was originally `full_week?`, same behavior as before)
  -  `between`
  -  `cache_between`
  -  `available_regions` (renamed method, was originally `regions`, same behavior as before)
  -  `load_custom`
* All generated definitions are now loaded when `require 'holidays'` is called
  - Previously files were required 'on the fly' when a specific region was specified. By requiring all definitions upon
    startup we greatly simplify the handling of regions, definitions, and custom methods internally
  - This results in a performance hit when calling `require 'holidays'`. Here is an example based on my benchmarking:
    - old: `0.045537`
    - new: `0.145125`

I decided that this performance hit on startup is acceptable. All other performance should remain the same. If performance is
a major concern please open an issue so we can discuss your use case.

## 3.3.0

This is the final minor point release in v3.X.X. I am releasing it so that all of the latest definitions can be
used by anyone that is not ready to jump to version 4.0.0. I am not planning on supporting this version unless a major
issue is found that needs to be immediately addressed.

* Update public holidays for Argentina (https://github.com/schmierkov)
* Remove redundant `require` from weekend modifier (https://github.com/Eric-Guo)
* FIX: Easter Saturday not a holiday in NZ (https://github.com/ghiculescu)
* FIX: Japan 'Marine Day' for 1996-2002 year ranges (https://github.com/shuhei)
* FIX: Australia calculations for Christmas and Boxing (https://github.com/ghiculescu)
* Add dutch language version of definitions for Belgium (michael.cox@novalex.be)
* Make 'Goede Vrijdag' informal for NL definitions (https://github.com/MathijsK93)
* Add 'Great Friday' to Czech holidays (juris@uol.cz)
* Add new informal holidays for Germany (https://github.com/knut2)
* FIX: correctly check for new `year_range` attribute in holidays by month repository (https://github.com/knut2)
* Add DE-Reformationstag for 2017 (https://github.com/knut2)
* Update Australia QLD definition Queens Bday and Labour Day (https://github.com/ghiculescu)

## 3.2.0

* add 'valid year' functionality to definitions - https://github.com/holidays/holidays/issues/33 - (thanks to https://github.com/ttwo32)
* Fix 'day after thanksgiving' namespace bug during definition generation (thanks to https://github.com/ttwo32)
* fix Danish holidays 'palmesondag and 1/5 (danish fightday)' to set to informal (thanks to https://github.com/bjensen)

## 3.1.2

* Do not require Date monkeypatching in definitions to use mday calculations (thanks to https://github.com/CloCkWeRX)

## 3.1.1

* Require 'digest/md5' in main 'holidays' module. This was missed during the refactor (thanks to https://github.com/espen)

## 3.1.0

* Fix St. Stephen observance holiday for Ireland (https://github.com/gumchum)
* Add Bulgarian holidays (https://github.com/thekazak)
* Add new mountain holiday for Japan (https://github.com/ttwo32)
* Add ability to calculate Easter in either Gregorian (existing) or Julian (new) dates

## 3.0.0

* Major refactor! Lots of code moved around and some methods were removed from the public api (they were never intended to be public).
* Only supports ruby 2.0.0 and up. Travis config has been updated to reflect this.
* Moves 'date' monkeypatching out of main lib and makes it a core extension. See README for usage.
* Fixes remote execution bug in issue-86 (thanks to https://github.com/Intrepidd for reporting)
* No region definition changes.

I decided to make this a major version bump due to how much I changed. I truly hope no one will notice.
See the README for the usage. It has, except for the date core extension, not changed.

## 2.2.0

* Correct 'informal' type for Dodenherdenking holiday in NL definitions (https://github.com/MathijsK93)

## 2.1.0

* Updated Slovak holiday definitions (https://github.com/guitarman)
* Fix Japanese non-Monday substitute holidays (https://github.com/shuhei)
* Fixed typo in Slovak holiday definitions (https://github.com/martinsabo)
* Updated New Zealand definitions to reflect new weekend-to-monday rules (https://github.com/SebastianEdwards)
* Fix Australian definitions (https://github.com/ghiculescu)

## 2.0.0

* Add test coverage
* Remove support for Ruby 1.8.7 and REE. (https://github.com/itsmechlark)
* Add support for Ruby 2.2 (https://github.com/itsmechlark)
* Add PH holidays (https://github.com/itsmechlark)
* Belgian holidays now written in French instead of English (https://github.com/maximerety)
* Update California (USA) holidays to include Cesar Chavez and Thanksgiving (https://github.com/evansagge)

## 1.2.0

* Remove inauguration day from USA Federal Reserve definitions (https://github.com/aripollak)
* Add caching functionality for date ranges (https://github.com/ndbroadbent & https://github.com/ghiculescu)

## 1.1.0

* Add support to load custom holidays on the fly
* Add hobart & launceston show days (https://github.com/ghiculescu)
* Add Melbourne Cup day (https://github.com/ghiculescu)
* Add Hobart Regatte Day (https://github.com/ghiculescu)
* Add Costa Rican holidays (https://github.com/kevinwmerritt)
* Update Canadian Holidays (https://github.com/KevinBrowne)
* Add substitute holidays for Japan (https://github.com/YoshiyukiHirano)
* Fix USA Federal Reserve Holidays
* Add FedEx holidays (https://github.com/adamrunner)

## 1.0.7

* Load parent region even when sub region is not explicitly defined (https://github.com/csage)
* Full support for http://en.wikipedia.org/wiki/ISO_3166-2:DE (https://github.com/rojoko)
* Added Lithuanian definitions (https://github.com/Brunas)
* Added Chilean definitions (https://github.com/marcelo-soto)g
* Added European Central Bank TARGET definitions (Toby Bryans, NASDAQ OMX NLX)
* FR: Make Pâques and Pentecôte informal holidays (https://github.com/wizcover)
* NL: Update for the new King (https://github.com/johankok)
* Added Slovenian definitions (https://github.com/bbalon)

## 1.0.6

* Added `Holidays.regions` method (https://github.com/sonnym)
* Added Slovakian definitions (https://github.com/mirelon)
* Added Venezuelan definitions (https://github.com/Chelo)
* Updated Canadian definitions (https://github.com/sdavies)
* Updated Argentinian definitions (https://github.com/popox)
* Updated Australian definitions (https://github.com/ghiculescu)
* Updated Portuguese definitions (https://github.com/MiPereira)
* Added Swiss definitions (https://github.com/samzurcher, https://github.com/jg)
* Added Romanian definitions (https://github.com/mtarnovan)
* Added Belgian definitions (https://github.com/jak78)
* Added Moroccan definitions (https://github.com/jak78)
* Fixes for New Year's and Boxing Day (https://github.com/iterion, https://github.com/andyw8)
* Fixes for Father's Day, Mother's Day and Armed Forces Day (https://github.com/eheikes)
* Typos (https://github.com/gregoriokusowski, https://github.com/popox)
* Added Croatian definitions (https://github.com/lecterror)
* Added US Federal Reserve holidays (https://github.com/willbarrett)
* Added NERC holidays (https://github.com/adamstrickland)
* Updated Irish holidays (https://github.com/xlcrs)

## 1.0.5

* Added `full_week?` method (https://github.com/dceddia)
* Added Portuguese definitions (https://github.com/pmor)
* Added Hungarian definitions (https://github.com/spap)
* Typos (https://github.com/DenisKnauf)

## 1.0.4

* Add Liechtenstein holiday defs (mercy vielmal Bernhard Furtmueller)

## 1.0.3

* Add Austrian holiday definitions (thanks to Vogel Siegfried)

## 1.0.2

* Add `orthodox_easter` method and Greek holiday definitions (thanks https://github.com/ddimitriadis)

## 1.0.0

* Support calculating mday from negative weeks other than -1 (thanks https://github.com/bjeanes)
* Use class method to check leap years and fixed bug in Date.calculate_mday (thanks https://github.com/dgrambow)
* Added Czech (thanks https://github.com/boblin), Brazilian (https://github.com/fabiokr), Norwegian (thanks to Peter Skeide) and Australia/Brisbane (https://github.com/bjeanes) definitions
* Cleaned up rake and gemspec

## 0.9.3

* Added New York Stock Exchange holidays (thank you Alan Larkin).
* Added UPS holidays (thank you Tim Anglade).
* Fixed rakefile to force lower case definition file names.

## 0.9.2

* Included rakefile in Gem (thank you James Herdman).

## 0.9.1

* au.yaml was being included incorrectly in US holiday definitions. Thanks to [Glenn Vanderburg](http://vanderburg.org/) for the fix.

## 0.9.0

* Initial release.
