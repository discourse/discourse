# frozen_string_literal: true

module DiscourseChatIntegration::Provider::SlackProvider
  class SlackMessageFormatter < Nokogiri::XML::SAX::Document
    attr_reader :excerpt

    def initialize
      @excerpt = +""
    end

    def self.format(html = "")
      me = self.new
      parser = Nokogiri::HTML4::SAX::Parser.new(me, Encoding::UTF_8.to_s)
      parser.parse(html)
      me.excerpt
    end

    def start_element(name, attributes = [])
      case name
      when "a"
        attributes = Hash[*attributes.flatten]
        @in_a = true
        @excerpt << "<#{absolute_url(attributes["href"])}|"
      end
    end

    def end_element(name)
      case name
      when "a"
        @excerpt << ">"
        @in_a = false
      end
    end

    def characters(string)
      string.strip! if @in_a
      @excerpt << string
    end

    private

    def absolute_url(url)
      uri =
        begin
          URI(url)
        rescue StandardError
          nil
        end

      return Discourse.current_hostname unless uri
      return uri.to_s if uri.scheme == "mailto"

      uri.host = Discourse.current_hostname if !uri.host
      uri.scheme = (SiteSetting.force_https ? "https" : "http") if !uri.scheme
      uri.to_s
    end
  end
end
