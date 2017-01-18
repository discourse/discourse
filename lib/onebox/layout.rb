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
        ::Onebox::Helpers.normalize_url_for_output(record[:link])
      end

      def domain
        record[:domain] || URI(link || '').host.to_s.sub(/^www\./, '')
      end

      def metadata_1_label
        record[:metadata_1_label]
      end

      def metadata_1_value
        record[:metadata_1_value]
      end

      def metadata_2_label
        record[:metadata_2_label]
      end

      def metadata_2_value
        record[:metadata_2_value]
      end

      def details
        {
          link: record[:link],
          title: record[:title],
          domain: domain,
          metadata_1_label: record[:metadata_1_label],
          metadata_1_value: record[:metadata_1_value],
          metadata_2_label: record[:metadata_2_label],
          metadata_2_value: record[:metadata_2_value],
          subname: view.template_name,
          view: view.to_html
        }
      end
  end
end
