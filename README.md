onebox
----------

  - [![Gem Version](https://badge.fury.io/rb/onebox.png)](https://rubygems.org/gems/onebox)
  - [![Code Climate](https://codeclimate.com/github/dysania/onebox.png)](https://codeclimate.com/github/dysania/onebox)
  - [![Build Status](https://travis-ci.org/dysania/onebox.png)](https://travis-ci.org/dysania/onebox)
  - [![Dependency Status](https://gemnasium.com/dysania/onebox.png)](https://gemnasium.com/dysania/onebox)
  - [![Coverage Status](https://coveralls.io/repos/dysania/onebox/badge.png)](https://coveralls.io/r/dysania/onebox)


Onebox is a library for turning media URLs into simple HTML previews of the resource.


Usage
=====

Using onebox is fairly simple!
First, make sure the library is required:

``` ruby
require "onebox"
```

Then pass a link to the library's interface:

``` ruby
require "onebox"

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url)
```

This will contain a simple Onebox::Preview object that handles all the transformation.
From here you either call `Onebox::Preview#to_s` or just pass the object to a string:

``` ruby
require "onebox"

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url)
"#{preview}" == preview.to_s #=> true
```

Onebox has its own caching system but you can also provide (or turn off) your own system:

``` ruby
require "onebox"

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url, cache: Rails.cache)
"#{preview}" == preview.to_s #=> true
```

In addition you can set your own defaults with this handy interface:

``` ruby
require "onebox"

Onebox.defaults = {
  cache: Rails.cache
}

url = "http://www.amazon.com/gp/product/B005T3GRNW/ref=s9_simh_gw_p147_d0_i2"
preview = Onebox.preview(url)
"#{preview}" == preview.to_s #=> true
```


Setup
=====

  1. Create new onebox engine

    ``` ruby
    # in lib/onebox/engine/name_onebox.rb

    module Onebox
      module Engine
        class NameOnebox
          include Engine
          include HTML

          private

          def data
            {
              url: @url,
              name: raw.css("h1").inner_text,
              image: raw.css("#main-image").first["src"],
              description: raw.css("#postBodyPS").inner_text
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
      let(:link) { "http://example.com" }
      let(:html) { described_class.new(link).to_html }

      before do
        fake(link, response("name.response"))
      end

      it "has the video's title" do
        expect(html).to include("title")
      end

      it "has the video's still shot" do
        expect(html).to include("photo.jpg")
      end

      it "has the video's description" do
        expect(html).to include("description")
      end

      it "has the URL to the resource" do
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
        <h2 class="host">example.com</h2>
        <img src="{{image}}" />
        <p>{{description}}</p>
      </a>
    </div>
    ```

  4. Create new fixture from HTML response

    ``` bash
    curl --output spec/fixtures/oneboxname.response -L -X -GET http://example.com
    ```

  5. Require in Engine module

    ``` ruby
    # in lib/onebox/engine/engine.rb
    require_relative "engine/name_onebox"
    ```
    
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
  - GitHub
    - Blob
    - Commit
    - Gist
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
  - SmugMug
  - SoundCloud
  - Stack Exchange
  - TED
  - Twitter
  - Wikipedia
  - yFrog


Installing
==========

Add this line to your application's Gemfile:

    gem "onebox". "~> 1.0"

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
