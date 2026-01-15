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
      # YouTube's oEmbed for reliable metadata (thumbnails, titles)
      add_oembed_provider(/youtube\.com|youtu\.be/, "https://www.youtube.com/oembed")

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
        enhance_title_with_anchor
        enhance_description_with_anchor

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

      def set_from_normalizer_data(normalizer, skip_dimensions: false)
        normalizer.data.each do |k, _|
          next if skip_dimensions && k.in?(%i[width height])
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
        skip_dimensions = oembed.data[:type] == "rich"
        set_from_normalizer_data(oembed, skip_dimensions:)
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

      def enhance_description_with_anchor
        return unless html_doc

        fragment = extract_url_fragment
        return if fragment.blank?

        section_description = find_section_description(fragment)
        return if section_description.blank?

        cleaned_description = clean_section_description(section_description)
        return if cleaned_description.blank?
        return if @raw[:description].present? && @raw[:description].include?(cleaned_description)

        if @raw[:description].present?
          @raw[:description] = "#{cleaned_description} | #{@raw[:description]}"
        else
          @raw[:description] = cleaned_description
        end
      end

      def find_section_description(fragment)
        target = find_anchor_target(fragment)
        return nil unless target

        extract_description_from_target(target)
      end

      def find_anchor_target(fragment)
        html_doc.at_xpath("//*[@id='#{fragment.gsub("'", "\\'")}']") ||
          html_doc.at_xpath("//a[@name='#{fragment.gsub("'", "\\'")}']") ||
          html_doc.at_css("##{CSS.escape(fragment)}")
      end

      def extract_description_from_target(target)
        parent_article = target.ancestors("article, section, details, .docstring").first
        search_context = parent_article || target.parent || target

        paragraph = search_context.at_css("p:not(.admonition-header)")
        return paragraph.text.strip if paragraph&.text&.strip.present?

        next_p = target.at_xpath("following-sibling::p[1]") || target.at_xpath("following::p[1]")
        return next_p.text.strip if next_p&.text&.strip.present?

        nil
      end

      def clean_section_description(text)
        cleaned = text.gsub(/\s+/, " ").strip
        cleaned.truncate(300, separator: " ", omission: "…")
      end

      def enhance_title_with_anchor
        return unless html_doc
        return if @raw[:title].blank?

        fragment = extract_url_fragment
        return if fragment.blank?

        section_title = find_section_title(fragment)
        return if section_title.blank?

        cleaned_title = clean_section_title(section_title)
        return if cleaned_title.blank?
        return if @raw[:title].include?(cleaned_title)

        @raw[:title] = "#{cleaned_title} - #{@raw[:title]}"
      end

      def extract_url_fragment
        uri = URI.parse(url)
        fragment = uri.fragment
        return nil if fragment.blank?

        CGI.unescape(fragment)
      rescue URI::InvalidURIError
        nil
      end

      def find_section_title(fragment)
        target = find_anchor_target(fragment)
        return nil unless target

        return target.text.strip if target.name =~ /^h[1-6]$/i

        code_content = target.at_css("code, .docstring-binding")&.text&.strip
        return code_content if code_content.present?

        heading = target.at_css("h1, h2, h3, h4, h5, h6")
        return heading.text.strip if heading

        find_nearest_heading(target)
      end

      def find_nearest_heading(element)
        current = element
        while current&.element?
          current.previous_element&.tap do |prev|
            return prev.text.strip if prev.name =~ /^h[1-6]$/i
          end
          current = current.parent
          return current.text.strip if current&.element? && current.name =~ /^h[1-6]$/i
        end
        nil
      end

      def clean_section_title(text)
        cleaned = text.gsub(/[\u00B6\u00A7#]/, "").gsub(/\s+/, " ").strip
        cleaned.truncate(80, separator: " ")
      end
    end
  end
end
