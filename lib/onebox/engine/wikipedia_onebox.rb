# frozen_string_literal: true

module Onebox
  module Engine
    class WikipediaOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_domain("wikipedia.com", "wikipedia.org", allow_subdomains: true)
      always_https

      def self.matches_path(path)
        true # Matches any path under the specified domains
      end

      private

      def data
        paras = []
        text = ""

        # Detect section Hash in the url and retrive the related paragraphs. if no hash provided the first few paragraphs will be used
        # Author Lidlanca
        # Date 9/8/2014
        if (m_url_hash = @url.match(%r{#([^/?]+)})) # extract url hash
          m_url_hash_name = m_url_hash[1]
        end

        if m_url_hash.nil? # no hash found in url
          paras = raw.search("p") # default get all the paras
        else
          section_header_title =
            raw.xpath(
              "//*[@id=\"#{CGI.unescape(m_url_hash_name)}\"][self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6]",
            )

          if section_header_title.empty?
            paras = raw.search("p") # default get all the paras
          else
            section_title_text = section_header_title.inner_text

            # Get .mw-heading which wraps the h* element
            cur_element = section_header_title[0].parent

            # p|text|div covers the general case. We assume presence of at least 1 P node. if section has no P node we may end up with a P node from the next section.
            # div tag is commonly used as an assets wraper in an article section. often as the first element holding an image.
            # ul support will imporve the output generated for a section with a list as the main content (for example: an Author Bibliography, A musician Discography, etc)
            first_p_found = nil
            while (
                    ((next_sibling = cur_element.next_sibling).name =~ /p|text|div|ul/) ||
                      first_p_found.nil?
                  )
              # from section header get the next sibling until it is a breaker tag
              cur_element = next_sibling
              if (cur_element.name == "p" || cur_element.name == "ul") #we treat a list as we detect a p to avoid showing
                first_p_found = true
                paras.push(cur_element)
              end
            end
          end
        end

        unless paras.empty?
          cnt = 0
          while text.length < Onebox::LayoutSupport.max_text && cnt <= 3
            break if cnt >= paras.size
            text += " " unless cnt == 0

            if paras[cnt].name == "ul" # Handle UL tag. Generate a textual ordered list (1.item | 2.item | 3.item). Unfortunately no newline allowed in output
              li_index = 1
              list_items = []
              paras[cnt]
                .children
                .css("li")
                .each do |li|
                  list_items.push "#{li_index}." + li.inner_text
                  li_index += 1
                end
              paragraph = (list_items.join " |\n ")[0..Onebox::LayoutSupport.max_text]
            else
              paragraph = paras[cnt].inner_text[0..Onebox::LayoutSupport.max_text]
            end

            paragraph.gsub!(/\[\d+\]/mi, "")
            text += paragraph
            cnt += 1
          end
        end

        text = "#{text[0..Onebox::LayoutSupport.max_text]}..." if text.length >
          Onebox::LayoutSupport.max_text

        result = {
          link: link,
          title:
            raw.css("html body h1").inner_text +
              (section_title_text ? " | " + section_title_text : ""), #if a section sub title exists add it to the main article title
          description: text,
        }

        img = raw.css(".infobox-image img")

        if img && img.size > 0
          img.each do |i|
            src = i["src"]
            if src !~ /Question_book/
              result[:image] = src
              break
            end
          end
        end

        result
      end
    end
  end
end
