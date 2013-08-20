require_relative "engine/open_graph"
require_relative "engine/example"
require_relative "engine/amazon"
require_relative "engine/qik"
require_relative "engine/stackexchange"
require_relative "engine/wikipedia"
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
      self.class.name.split("::").last.downcase
    end
  end
end
