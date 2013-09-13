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

``` ruby
require "onebox"
```

The `Gemfile` file would look like this:

``` ruby
# source/Gemfile
source "https://rubygems.org"

gem "onebox", "~> 1.0"
```

How to create a new onebox
===========================

1. Create new onebox engine

``` ruby
# in lib/onebox/engine/name_onebox.rb

module Onebox
  module Engine
    class NameOnebox
      include Engine

      private

      def extracted_data
        {
          url: @url,
          name: @body.css("h1").inner_text,
          image: @body.css("#main-image").first["src"],
          description: @body.css("#postBodyPS").inner_text
        }
      end
    end
  end
end
```

2. Create new onebox spec

``` ruby
# in spec/lib/onebox/engine/name_spec.rb
require "spec_helper"

describe Onebox::Engine::NameOnebox do
  let(:link) { "http://yoursitename.com" }
  let(:html) { described_class.new(link).to_html }

  before do
    fake(link, response("name.response"))
  end

  it "returns video title" do
    expect(html).to include("title")
  end

  it "returns video photo" do
    expect(html).to include("photo.jpg")
  end

  it "returns video description" do
    expect(html).to include("description")
  end

  it "returns URL" do
    expect(html).to include(link)
  end
end
```

3. Create new handlebars template

``` html
# in templates/name.handlebars
<div class="onebox">
  <a href="{{url}}">
    <h1>{{name}}</h1>
    <h2 class="host">yoursitename.com</h2>
    <img src="{{image}}" />
    <p>{{description}}</p>
  </a>
</div>
```

4. Create new fixture from HTML response

``` bash
curl --output spec/fixtures/name.response -L -X -GET http://yoursitename.com
```

5. Require in Engine module

``` ruby
# in lib/onebox/engine/engine.rb
require_relative "engine/name_onebox"
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
