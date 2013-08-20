require_relative "engine/open_graph"
require_relative "engine/example_onebox"
require_relative "engine/amazon_onebox"
require_relative "engine/qik_onebox"
require_relative "engine/stack_exchange_onebox"
require_relative "engine/wikipedia_onebox"
require_relative "engine/flickr"

module Onebox
  module Engine
    def initialize(link)
      @url = link
      @body = read
      @data = extracted_data
    end

    def to_html
      Mustache.render(template, @data)
    end

    def read
      Nokogiri::HTML(open(@url))
    end

    def template
      File.read(File.join("templates", "#{template_name}.handlebars"))
    end

    def template_name
      self.class.name.split("::").last.downcase.gsub(/onebox/, "")
    end
  end
end
