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

    attr_reader :cache

    def initialize(link, cache = Onebox.defaults)
      @url = link
      @cache = cache
    end

    def to_html
      Mustache.render(template, record)
    end

    private

    def record
      if cache.key?(@url)
        cache.fetch(@url)
      else
        cache.store(@url, data)
      end
    end

    # raises error if not defined in onebox engine
    # in each onebox, uses either Nokogiri or OpenGraph to get raw HTML from url
    def raw
      raise NoMethodError, "Engines need to implement this method"
    end

    def template
      File.read(template_path)
    end

    def template_path
      File.join(root, "templates", "#{template_name}.handlebars")
    end

    # returns the gem root directory
    def root
      Gem::Specification.find_by_name("onebox").gem_dir
    end

    # calculates handlebars template name for onebox using name of engine
    def template_name
      self.class.name.split("::").last.downcase.gsub(/onebox/, "")
    end

    # raises error if not defined in onebox engine
    # in each onebox, returns hash of desired onebox content
    def data
      raise NoMethodError, "Engines need this method defined"
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
        class_variable_set :@@matcher, VerEx.new(&block)
      end
    end
  end
end

require_relative "engine/open_graph"
require_relative "engine/html"
require_relative "engine/json"
require_relative "engine/example_onebox"
require_relative "engine/amazon_onebox"
require_relative "engine/bliptv_onebox"
require_relative "engine/clikthrough_onebox"
require_relative "engine/college_humor_onebox"
require_relative "engine/dailymotion_onebox"
require_relative "engine/dotsub_onebox"
require_relative "engine/flickr_onebox"
require_relative "engine/funny_or_die_onebox"
require_relative "engine/github_commit_onebox"
require_relative "engine/github_gist_onebox"
require_relative "engine/hulu_onebox"
require_relative "engine/nfb_onebox"
require_relative "engine/sound_cloud_onebox"
require_relative "engine/spotify_onebox"
require_relative "engine/qik_onebox"
require_relative "engine/revision3_onebox"
require_relative "engine/slideshare_onebox"
require_relative "engine/stack_exchange_onebox"
require_relative "engine/ted_onebox"
require_relative "engine/viddler_onebox"
require_relative "engine/vimeo_onebox"
require_relative "engine/wikipedia_onebox"
require_relative "engine/yfrog_onebox"
