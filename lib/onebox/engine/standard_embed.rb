# frozen_string_literal: true

require "cgi"
require "onebox/normalizer"
require "onebox/open_graph"
require "onebox/oembed"
require "onebox/json_ld"

module Onebox
  module Engine
    module StandardEmbed
      def self.oembed_providers
        @@oembed_providers ||= {}
      end

      def self.add_oembed_provider(regexp, endpoint)
        oembed_providers[regexp] = endpoint
      end

      def self.opengraph_providers
        @@opengraph_providers ||= []
      end

      def self.add_opengraph_provider(regexp)
        opengraph_providers << regexp
      end

      # Some oembed providers (like meetup.com) don't provide links to themselves
      add_oembed_provider(%r{www\.meetup\.com/}, "http://api.meetup.com/oembed")
      add_oembed_provider(%r{www\.mixcloud\.com/}, "https://www.mixcloud.com/oembed/")
      # In order to support Private Videos
      add_oembed_provider(%r{vimeo\.com/}, "https://vimeo.com/api/oembed.json")
      # NYT requires login so use oembed only
      add_oembed_provider(%r{nytimes\.com/}, "https://www.nytimes.com/svc/oembed/json/")

      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts) || super
      end

      def raw
        return @raw if defined?(@raw)

        @raw = {}

        set_opengraph_data_on_raw
        set_twitter_data_on_raw
        set_oembed_data_on_raw
        set_json_ld_data_on_raw
        set_favicon_data_on_raw
        set_description_on_raw

        @raw
      end

      protected

      def html_doc
        return @html_doc if defined?(@html_doc)

        headers = nil
        headers = { "Cookie" => options[:cookie] } if options[:cookie]

        @html_doc = Onebox::Helpers.fetch_html_doc(url, headers)
      end

      def get_oembed
        @oembed ||= Onebox::Oembed.new(get_json_response)
      end

      def get_opengraph
        @opengraph ||= ::Onebox::OpenGraph.new(html_doc)
      end

      def get_twitter
        return {} unless html_doc

        twitter = {}

        html_doc
          .css("meta")
          .each do |m|
            if (m["property"] && m["property"][/^twitter:(.+)$/i]) ||
                 (m["name"] && m["name"][/^twitter:(.+)$/i])
              value = (m["content"] || m["value"]).to_s
              twitter[$1.tr("-:", "_").to_sym] ||= value if (value.present? && value != "0 minutes")
            end
          end

        twitter
      end

      def get_favicon
        return nil unless html_doc

        favicon =
          html_doc.css(
            'link[rel="shortcut icon"], link[rel="icon shortcut"], link[rel="shortcut"], link[rel="icon"]',
          ).first
        favicon = favicon.nil? ? nil : (favicon["href"].nil? ? nil : favicon["href"].strip)

        return nil if favicon.blank?

        absolute_url = Onebox::Helpers.get_absolute_image_url(favicon, url)

        return nil if absolute_url.length > UrlHelper::MAX_URL_LENGTH

        absolute_url
      end

      def get_description
        return nil unless html_doc

        description = html_doc.at("meta[name='description']").to_h["content"]
        description ||= html_doc.at("meta[name='Description']").to_h["content"]

        description
      end

      def get_json_response
        oembed_url = get_oembed_url

        return "{}" if oembed_url.blank?

        begin
          Onebox::Helpers.fetch_response(oembed_url)
        rescue StandardError
          "{}"
        end
      rescue Errno::ECONNREFUSED, Net::HTTPError, Net::HTTPFatalError, MultiJson::LoadError
        "{}"
      end

      def get_oembed_url
        oembed_url = nil

        StandardEmbed.oembed_providers.each do |regexp, endpoint|
          if url =~ regexp
            oembed_url = "#{endpoint}?url=#{url}"
            break
          end
        end

        if html_doc
          if oembed_url.blank?
            application_json = html_doc.at("//link[@type='application/json+oembed']/@href")
            oembed_url = application_json.value if application_json
          end

          if oembed_url.blank?
            text_json = html_doc.at("//link[@type='text/json+oembed']/@href")
            oembed_url ||= text_json.value if text_json
          end
        end

        oembed_url
      end

      def get_json_ld
        @json_ld ||= Onebox::JsonLd.new(html_doc)
      end

      def set_from_normalizer_data(normalizer)
        normalizer.data.each do |k, _|
          v = normalizer.public_send(k)
          @raw[k] ||= v unless v.nil?
        end
      end

      def set_opengraph_data_on_raw
        og = get_opengraph
        set_from_normalizer_data(og)
        @raw.except!(:title_attr)
      end

      def set_twitter_data_on_raw
        twitter = get_twitter
        twitter.each { |k, v| @raw[k] ||= v if v.present? }
      end

      def set_oembed_data_on_raw
        oembed = get_oembed
        set_from_normalizer_data(oembed)
      end

      def set_json_ld_data_on_raw
        json_ld = get_json_ld
        set_from_normalizer_data(json_ld)
      end

      def set_favicon_data_on_raw
        favicon = get_favicon
        @raw[:favicon] = favicon if favicon.present?
      end

      def set_description_on_raw
        unless @raw[:description]
          description = get_description
          @raw[:description] = description if description.present?
        end
      end
    end
  end
end
