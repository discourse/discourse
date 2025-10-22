# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class WebBrowser < Tool
        def self.signature
          {
            name: name,
            description:
              "Visits a web page, retrieves the HTML content, extracts the main content, converts it to plain text, and returns the result.",
            parameters: [
              {
                name: "url",
                description: "The URL of the web page to visit.",
                required: true,
                type: "string",
              },
            ],
          }
        end

        def self.name
          "web_browser"
        end

        def url
          return @url if defined?(@url)
          @url = parameters[:url]
          @url = "https://#{@url}" if !@url.start_with?("http")

          @url
        end

        def invoke
          send_http_request(url, follow_redirects: true) do |response|
            if response.code == "200"
              html = read_response_body(response)
              text = extract_main_content(html)
              text = truncate(text, max_length: 50_000, percent_length: 0.3, llm: llm)
              return { url: response.uri.to_s, text: text.strip }
            else
              return { url: url, error: "Failed to retrieve the web page: #{response.code}" }
            end
          end

          { url: url, error: "Failed to retrieve the web page" }
        rescue StandardError
          # keeping information opaque for now just in case
          { url: url, error: "Failed to retrieve the web page" }
        end

        def description_args
          { url: url }
        end

        private

        def extract_main_content(html)
          doc = Nokogiri.HTML(html)
          doc.search("script, style, comment").remove

          main_content = find_main_content(doc)
          main_content ||= doc.at("body")

          buffer = +""
          nodes_to_text(main_content, buffer)

          buffer.gsub(/\s+/, " ")
        end

        def nodes_to_text(nodes, buffer)
          if nodes.text?
            buffer << nodes.text
            buffer << " "
            return
          end

          nodes.children.each do |node|
            case node.name
            when "text"
              buffer << node.text
              buffer << " "
            when "br"
              buffer << "\n"
            when "a"
              nodes_to_text(node, buffer)
              buffer << " [#{node["href"]}] "
            else
              nodes_to_text(node, buffer)
            end
          end
        end

        def find_main_content(doc)
          [
            doc.at("article"),
            doc.at("main"),
            doc.at("[role='main']"),
            doc.at("#main"),
            doc.at(".main"),
            doc.at("#content"),
            doc.at(".content"),
          ].find(&:present?)
        end
      end
    end
  end
end
