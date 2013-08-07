discourse-onebox
----------

  - TODO: register to rubygems.org
  - [![Code Climate](https://codeclimate.com/github/dysania/discourse-onebox.png)](https://codeclimate.com/github/dysania/discourse-onebox)
  - [![Build Status](https://travis-ci.org/dysania/discourse-onebox.png)](https://travis-ci.org/dysania/discourse-onebox)
  - [![Dependency Status](https://gemnasium.com/dysania/discourse-onebox.png)](https://gemnasium.com/dysania/discourse-onebox)
  - [![Coverage Status](https://coveralls.io/repos/dysania/discourse-onebox/badge.png)](https://coveralls.io/r/dysania/discourse-onebox)


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


Using discourse-onebox
===============

You can include discourse-onebox modules into a class like so:

``` ruby
require "discourse-onebox"
```
TODO: write example



The `Gemfile` file would look like this:

``` ruby
# source/Gemfile
source "https://rubygems.org"

gem "discourse-onebox", "~> <%= version %>"
```


Installing discourse-onebox
==================

Add this line to your application's Gemfile:

    gem 'discourse-onebox'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install discourse-onebox


Contributing
============

  1. Fork it
  2. Create your feature branch (`git checkout -b my-new-feature`)
  3. Commit your changes (`git commit -am 'Add some feature'`)
  4. Push to the branch (`git push origin my-new-feature`)
  5. Create new Pull Request
