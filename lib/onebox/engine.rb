# frozen_string_literal: true

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

    def self.all_iframe_origins
      engines.flat_map { |e| e.iframe_origins }.uniq.compact
    end

    def self.origins_to_regexes(origins)
      return [/.*/] if origins.include?("*")

      origins.map do |origin|
        escaped_origin = Regexp.escape(origin)
        if origin.start_with?("*.", "https://*.", "http://*.")
          escaped_origin = escaped_origin.sub("\\*", '\S*')
        end

        Regexp.new("\\A#{escaped_origin}", 'i')
      end
    end

    attr_reader :url, :uri, :options, :timeout
    attr :errors

    def options=(opt)
      return @options if opt.nil? # make sure options provided
      opt = opt.to_h if opt.instance_of?(OpenStruct)
      @options.merge!(opt)
      @options
    end

    def initialize(url, timeout = nil)
      @errors = {}
      @options = {}
      class_name = self.class.name.split("::").last.to_s

      # Set the engine options extracted from global options.
      self.options = Onebox.options[class_name] || {}

      @url = url
      @uri = URI(url)
      if always_https?
        @uri.scheme = 'https'
        @url = @uri.to_s
      end
      @timeout = timeout || Onebox.options.timeout
    end

    # raises error if not defined in onebox engine.
    # This is the output method for an engine.
    def to_html
      fail NoMethodError, "Engines need to implement this method"
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

    # raises error if not defined in onebox engine
    # in each onebox, uses either Nokogiri or StandardEmbed to get raw HTML from url
    def raw
      fail NoMethodError, "Engines need to implement this method"
    end

    # raises error if not defined in onebox engine
    # in each onebox, returns hash of desired onebox content
    def data
      fail NoMethodError, "Engines need this method defined"
    end

    def link
      ::Onebox::Helpers.uri_encode(@url)
    end

    def always_https?
      self.class.always_https?
    end

    module ClassMethods
      def handles_content_type?(other)
        if other && class_variable_defined?(:@@matcher_content_type)
          !!(other.to_s =~ class_variable_get(:@@matcher_content_type))
        end
      end

      def ===(other)
        if other.kind_of?(URI)
          !!(other.to_s =~ class_variable_get(:@@matcher))
        else
          super
        end
      end

      def priority
        100
      end

      def matches_regexp(r)
        class_variable_set :@@matcher, r
      end

      def matches_content_type(ct)
        class_variable_set :@@matcher_content_type, ct
      end

      def requires_iframe_origins(*origins)
        class_variable_set :@@iframe_origins, origins
      end

      def iframe_origins
        class_variable_defined?(:@@iframe_origins) ? class_variable_get(:@@iframe_origins) : []
      end

      # calculates a name for onebox using the class name of engine
      def onebox_name
        name.split("::").last.downcase.gsub(/onebox/, "")
      end

      def always_https
        @https = true
      end

      def always_https?
        defined?(@https) ? @https : false
      end
    end
  end
end

require_relative "helpers"
require_relative "layout_support"
require_relative "file_type_finder"
require_relative "engine/standard_embed"
require_relative "engine/html"
require_relative "engine/json"
require_relative "engine/amazon_onebox"
require_relative "engine/github_issue_onebox"
require_relative "engine/github_blob_onebox"
require_relative "engine/github_commit_onebox"
require_relative "engine/github_folder_onebox"
require_relative "engine/github_gist_onebox"
require_relative "engine/github_pull_request_onebox"
require_relative "engine/google_calendar_onebox"
require_relative "engine/google_docs_onebox"
require_relative "engine/google_maps_onebox"
require_relative "engine/google_play_app_onebox"
require_relative "engine/image_onebox"
require_relative "engine/video_onebox"
require_relative "engine/audio_onebox"
require_relative "engine/stack_exchange_onebox"
require_relative "engine/twitter_status_onebox"
require_relative "engine/wikimedia_onebox"
require_relative "engine/wikipedia_onebox"
require_relative "engine/youtube_onebox"
require_relative "engine/youku_onebox"
require_relative "engine/allowlisted_generic_onebox"
require_relative "engine/pubmed_onebox"
require_relative "engine/sound_cloud_onebox"
require_relative "engine/imgur_onebox"
require_relative "engine/pastebin_onebox"
require_relative "engine/slides_onebox"
require_relative "engine/xkcd_onebox"
require_relative "engine/animated_image_onebox"
require_relative "engine/gfycat_onebox"
require_relative "engine/typeform_onebox"
require_relative "engine/vimeo_onebox"
require_relative "engine/steam_store_onebox"
require_relative "engine/sketch_fab_onebox"
require_relative "engine/audioboom_onebox"
require_relative "engine/replit_onebox"
require_relative "engine/asciinema_onebox"
require_relative "engine/mixcloud_onebox"
require_relative "engine/band_camp_onebox"
require_relative "engine/coub_onebox"
require_relative "engine/flickr_onebox"
require_relative "engine/flickr_shortened_onebox"
require_relative "engine/five_hundred_px_onebox"
require_relative "engine/pdf_onebox"
require_relative "engine/twitch_clips_onebox"
require_relative "engine/twitch_stream_onebox"
require_relative "engine/twitch_video_onebox"
require_relative "engine/trello_onebox"
require_relative "engine/cloud_app_onebox"
require_relative "engine/wistia_onebox"
require_relative "engine/simplecast_onebox"
require_relative "engine/instagram_onebox"
require_relative "engine/gitlab_blob_onebox"
require_relative "engine/google_photos_onebox"
require_relative "engine/kaltura_onebox"
require_relative "engine/reddit_media_onebox"
require_relative "engine/google_drive_onebox"
require_relative "engine/facebook_media_onebox"
require_relative "engine/hackernews_onebox"
