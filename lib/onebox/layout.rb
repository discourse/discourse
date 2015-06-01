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

    def details
      {
        link: record[:link],
        title: record[:title],
        domain: domain,
        subname: view.template_name,
        view: view.to_html
      }
    end
  end
end
