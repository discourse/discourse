module Onebox
  module Engine
    class WikipediaOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp(/^https?:\/\/.*wikipedia\.(com|org)/)

      private

      def data
        paras = []
        text = ""

        # Detect section Hash in the url and retrive the related paragraphs.  if no hash provided the first few paragraphs will be used
        # Author Lidlanca
        # Date 9/8/2014
        if ( m_url_hash = @url.match /#([^\/?]+)/ ) #extract url hash
          m_url_hash_name= m_url_hash[1]
        end

        unless m_url_hash.nil?
          section_header_title = raw.xpath("//span[@id='#{m_url_hash_name}']") 

          if section_header_title.empty? 
            paras = raw.search("p") #default get all the paras
          else 
            section_title_text = section_header_title.inner_text
            section_header = section_header_title[0].parent #parent element of the section span element should be an <h3> node
            cur_element = section_header
            while ( (next_sibling = cur_element.next_sibling).name =~ /p|text|div/ ) do  #from section header get the next sibling until it is a not one of the tags <text> | <p> | <div>
                                                                                         #a div tag may be used as an assets wraper in an article section, it can't be a loop if a div is the 1st element in a section no p will be populated
              cur_element = next_sibling
              if cur_element.name == "p"
                paras.push(cur_element)
              end
            end
          end
        else # no hash found in url
          paras = raw.search("p") #default get all the paras
        end

        unless paras.empty?
          cnt = 0
          while text.length < Onebox::LayoutSupport.max_text && cnt <= 3
            break if cnt >= paras.size
            text << " " unless cnt == 0
            paragraph = paras[cnt].inner_text[0..Onebox::LayoutSupport.max_text]
            paragraph.gsub!(/\[\d+\]/mi, "")
            text << paragraph
            cnt += 1
          end
        end
        text = "#{text[0..Onebox::LayoutSupport.max_text]}..." if text.length > Onebox::LayoutSupport.max_text
        result = {
          link: link,
          title: raw.css("html body h1").inner_text + (section_title_text ? " | " + section_title_text : ""),  #if a section sub title exists add it to the main article title
          description: text
        }
        img = raw.css(".image img")
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
