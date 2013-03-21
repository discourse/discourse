module Oneboxer

  class << self
    def parse_open_graph(doc)
      result = {}

      %w(title type image url description).each do |prop|
        node = doc.at("/html/head/meta[@property='og:#{prop}']")
        result[prop] = (node['content'] || node['value']) if node
      end

      # If there's no title, try using the page's title
      if result['title'].blank?
        result['title'] = doc.title
      end

      # If there's no description, try and get one from the meta tags
      if result['description'].blank?
        node = doc.at("/html/head/meta[@name='description']")
        result['description'] = node['content'] if node
      end
      if result['description'].blank?
        node = doc.at("/html/head/meta[@name='Description']")
        result['description'] = node['content'] if node
      end

      result
    end
  end

  class Matcher
    attr_reader :regexp, :klass

    def initialize(klass)
      @klass = klass
      @regexp = klass.regexp
    end
  end

  module Base
    def matchers
      @matchers ||= []
    end

    def add_onebox(klass)
      matchers << Matcher.new(klass)
    end
  end

end
