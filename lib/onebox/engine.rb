module Onebox
  module Engine
    def self.included(object)
      object.extend(ClassMethods)
    end

    def self.engines
      constants.select do |constant|
        constant.to_s =~ /Onebox$/
      end.map(&method(:const_get))
    end

    attr_reader :url
    attr_reader :cache
    attr_reader :timeout

    def initialize(link, cache = nil, timeout = nil)
      @url = link
      @cache = cache || Onebox.options.cache
      @timeout = timeout || Onebox.options.timeout
    end

    # raises error if not defined in onebox engine. This is the output method for
    # an engine.
    def to_html
      raise NoMethodError, "Engines need to implement this method"
    end

    # Some oneboxes create iframes or other complicated controls. If you're using
    # a live editor with HTML preview, rendering those complicated controls can
    # be slow or cause flickering.
    #
    # This method allows engines to produce a placeholder such as static image
    # frame of a video.
    #
    # By default it just calls `to_html` unless implemented.
    def placeholder_html
      to_html
    end

    private

    def record
      if cache.key?(url)
        cache.fetch(url)
      else
        cache.store(url, data)
      end
    end

    # raises error if not defined in onebox engine
    # in each onebox, uses either Nokogiri or OpenGraph to get raw HTML from url
    def raw
      raise NoMethodError, "Engines need to implement this method"
    end

    # raises error if not defined in onebox engine
    # in each onebox, returns hash of desired onebox content
    def data
      raise NoMethodError, "Engines need this method defined"
    end

    def link
      @url.gsub(/['\"<>]/, CGI::TABLE_FOR_ESCAPE_HTML__)
    end

    module ClassMethods
      def ===(object)
        if object.kind_of?(String)
          !!(object =~ class_variable_get(:@@matcher))
        else
          super
        end
      end

      def matches(&block)
        class_variable_set :@@matcher, Hexpress.new(&block).to_r
      end

      # calculates a name for onebox using the class name of engine
      def onebox_name
        name.split("::").last.downcase.gsub(/onebox/, "")
      end

    end
  end
end

require_relative "layout_support"
require_relative "iframe_support"
require_relative "engine/open_graph"
require_relative "engine/html"
require_relative "engine/json"
require_relative "engine/amazon_onebox"
require_relative "engine/bliptv_onebox"
require_relative "engine/clikthrough_onebox"
require_relative "engine/college_humor_onebox"
require_relative "engine/dailymotion_onebox"
require_relative "engine/dotsub_onebox"
require_relative "engine/flickr_onebox"
require_relative "engine/funny_or_die_onebox"
require_relative "engine/github_blob_onebox"
require_relative "engine/github_commit_onebox"
require_relative "engine/github_gist_onebox"
require_relative "engine/github_pullrequest_onebox"
require_relative "engine/google_play_app_onebox"
require_relative "engine/hulu_onebox"
require_relative "engine/imgur_image_onebox"
require_relative "engine/itunes_onebox"
require_relative "engine/kinomap_onebox"
require_relative "engine/nfb_onebox"
require_relative "engine/qik_onebox"
require_relative "engine/revision3_onebox"
require_relative "engine/slideshare_onebox"
require_relative "engine/smug_mug_onebox"
require_relative "engine/sound_cloud_onebox"
require_relative "engine/spotify_onebox"
require_relative "engine/stack_exchange_onebox"
require_relative "engine/ted_onebox"
require_relative "engine/twitter_status_onebox"
require_relative "engine/viddler_onebox"
require_relative "engine/vimeo_onebox"
require_relative "engine/wikipedia_onebox"
require_relative "engine/yfrog_onebox"
