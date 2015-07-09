module Onebox
  module Engine
    class PubmedOnebox
      include Engine
      include LayoutSupport

      matches_regexp Regexp.new("^https?://(?:(?:\\w)+\\.)?(www.ncbi.nlm.nih)\\.gov(?:/)?/pubmed/")

      private

      def get_xml
        doc = Nokogiri::XML(open(URI.join(@url, "?report=xml&format=text")))
        pre = doc.xpath("//pre")
        Nokogiri::XML("<root>" + pre.text + "</root>")
      end

      def authors_of_xml(xml)
        initials = xml.css("Initials").map{|x| x.content}
        last_names = xml.css("LastName").map{|x| x.content}
        author_list = (initials.zip(last_names)).map{|i,l| i + " " + l}
        if author_list.length > 1 then
          author_list[-2] = author_list[-2] + " and " + author_list[-1]
          author_list.pop
        end
        author_list.join(", ")
      end

      def date_of_xml(xml)
        date_arr = (xml.css("PubDate")[0].children).map{|x| x.content}
        date_arr = date_arr.select{|s| !s.match(/^\s+$/)}
        date_arr = (date_arr.map{|s| s.split}).flatten
        date_arr.sort.reverse.join(" ") # Reverse sort so month before year.
      end

      def data
         xml = get_xml()
         {
         title: xml.css("ArticleTitle")[0].content,
         authors: authors_of_xml(xml),
         journal: xml.css("Title")[0].content,
         abstract: xml.css("AbstractText")[0].content,
         date: date_of_xml(xml),
         link: @url,
         pmid: match[:pmid]
        }
      end

      def match
        @match ||= @url.match(%r{www\.ncbi\.nlm\.nih\.gov/pubmed/(?<pmid>[0-9]+)})
      end
    end
  end
end
