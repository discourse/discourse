require 'open-uri'

module Oneboxer

  class BaseOnebox

    class << self
      attr_accessor :regexp
      attr_accessor :favicon_file

      def matcher(regexp=nil,&blk)
        self.regexp = regexp || blk
      end

      def favicon(favicon_file)
        self.favicon_file = "favicons/#{favicon_file}"
      end

      def remove_whitespace(s)
        s.gsub /\n/, ''
      end

      def image_html(url, title, page_url)
        "<a href='#{page_url}' target='_blank'><img src='#{url}' alt='#{title}'></a>"
      end

      def replace_tags_with_spaces(s)
        s.gsub /<[^>]+>/, ' '
      end

      def uriencode(val)
        URI.escape(val, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end

      # Replace any occurence of a HTTP or HTTPS URL in the string with the protocol-agnostic variant
      def replace_agnostic(var)
        var.gsub! /https?:\/\//, '//' if var.is_a? String
      end

    end

    def initialize(url, opts={})
      @url = url
      @opts = opts
    end

    def translate_url
      @url
    end

    def nice_host
      host = URI.parse(@url).host
      host.nil? ? '' : host.gsub('www.', '')
    rescue URI::InvalidURIError
      '' # In case there is a problem with the URL, we just won't set the host
    end
  end
end
