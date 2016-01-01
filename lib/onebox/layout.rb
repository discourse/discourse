require_relative "template_support"

module Onebox
  class Layout < Mustache
    include TemplateSupport

    VERSION = "1.0.0"

    attr_reader :cache
    attr_reader :record
    attr_reader :view

    def initialize(name, record, cache)
      @cache = cache
      @record = Onebox::Helpers.symbolize_keys(record)

      # Fix any relative paths
      if @record[:image] && @record[:image] =~ /^\/[^\/]/
        @record[:image] = "#{uri.scheme}://#{uri.host}/#{@record[:image]}"
      end

      @md5 = Digest::MD5.new
      @view = View.new(name, record)
      @template_name = "_layout"
      @template_path = load_paths.last
    end

    def to_html
      result = cache.fetch(checksum) { render(details) }
      cache[checksum] = result if cache.respond_to?(:key?)
      result
    end

    private

    def uri
      @uri = URI(link)
    end


    def checksum
      @md5.hexdigest("#{VERSION}:#{link}")
    end

    def link
      record[:link]
    end

    def domain
      return record[:domain] if record[:domain]
      URI(link || '').host
    end

    def repository_path
      record[:repository_path]
    end

    def twitter_label1
      record[:twitter_label1]
    end

    def twitter_data1
      record[:twitter_data1]
    end

    def twitter_label2
      record[:twitter_label2]
    end

    def twitter_data2
      record[:twitter_data2]
    end

    def details
      {
        link: record[:link],
        title: record[:title],
        domain: domain,
        repository_path: repository_path,
        twitter_label1: record[:twitter_label1],
        twitter_data1: record[:twitter_data1],
        twitter_label2: record[:twitter_label2],
        twitter_data2: record[:twitter_data2],
        subname: view.template_name,
        view: view.to_html
      }
    end
  end
end
