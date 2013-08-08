onebox
----------

  - TODO: register to rubygems.org
  - [![Code Climate](https://codeclimate.com/github/dysania/onebox.png)](https://codeclimate.com/github/dysania/onebox)
  - [![Build Status](https://travis-ci.org/dysania/onebox.png)](https://travis-ci.org/dysania/onebox)
  - [![Dependency Status](https://gemnasium.com/dysania/onebox.png)](https://gemnasium.com/dysania/onebox)
  - [![Coverage Status](https://coveralls.io/repos/dysania/onebox/badge.png)](https://coveralls.io/r/dysania/onebox)


Onebox is a library for turning media URLs into previews.

Onebox currently has support for page, image, and video URLs from these sites:
- Amazon
- Android App Store
- Apple Store
- BlipTV
- Clikthrough
- College Humor
- Dailymotion
- Dotsub
- Flickr
- Funny or Die
- Gist
- Github
    - Blob
    - Commit
    - Pull Request
- Hulu
- Imgur
- Kinomap
- NFB
- Open Graph
- Qik
- Revision
- Rotten Tomatoes
- Slideshare
- Smugmug
- Soundcloud
- Stack Exchange
- TED
- Twitter
- Wikipedia
- yFrog


Using onebox
===============

You can include onebox modules into a class like so:

``` ruby
require "onebox"
```
TODO: write example



The `Gemfile` file would look like this:

``` ruby
# source/Gemfile
source "https://rubygems.org"

gem "onebox", "~> <%= version %>"
```


Installing onebox
==================

Add this line to your application's Gemfile:

    gem 'onebox'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install onebox


Contributing
============

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Add some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request
