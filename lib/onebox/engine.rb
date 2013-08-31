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

    def initialize(link)
      @url = link
      @body = read
      @data = extracted_data
    end

    def to_html
      Mustache.render(template, @data)
    end

    private

    def read
      Nokogiri::HTML(open(@url))
    end

    def template
      File.read(File.join("templates", "#{template_name}.handlebars"))
    end

    def template_name
      self.class.name.split("::").last.downcase.gsub(/onebox/, "")
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
require_relative "engine/example_onebox"
require_relative "engine/amazon_onebox"
require_relative "engine/bliptv_onebox"
require_relative "engine/college_humor_onebox"
require_relative "engine/dotsub_onebox"
require_relative "engine/flickr_onebox"
require_relative "engine/funny_or_die_onebox"
require_relative "engine/hulu_onebox"
require_relative "engine/nfb_onebox"
require_relative "engine/qik_onebox"
require_relative "engine/stack_exchange_onebox"
require_relative "engine/vimeo_onebox"
require_relative "engine/wikipedia_onebox"
