# frozen_string_literal: true

module Onebox
  module Engine
    class PubmedOnebox
      include Engine
      include LayoutSupport

      matches_domain("ncbi.nlm.nih.gov", allow_subdomains: true)

      def self.matches_path(path)
        path.match?(%r{^/pubmed/\d+$})
      end

      private

      def xml
        return @xml if defined?(@xml)
        doc = Nokogiri.XML(URI.join(@url, "?report=xml&format=text").open)
        pre = doc.xpath("//pre")
        @xml = Nokogiri.XML("<root>" + pre.text + "</root>")
      end

      def authors
        initials = xml.css("Initials").map { |x| x.content }
        last_names = xml.css("LastName").map { |x| x.content }
        author_list = (initials.zip(last_names)).map { |i, l| i + " " + l }
        if author_list.length > 1
          author_list[-2] = author_list[-2] + " and " + author_list[-1]
          author_list.pop
        end
        author_list.join(", ")
      end

      def date
        xml
          .css("PubDate")
          .children
          .map { |x| x.content }
          .select { |s| !s.match(/^\s+$/) }
          .map { |s| s.split }
          .flatten
          .sort
          .reverse
          .join(" ") # Reverse sort so month before year.
      end

      def data
        {
          title: xml.css("ArticleTitle").text,
          authors: authors,
          journal: xml.css("Title").text,
          abstract: xml.css("AbstractText").text,
          date: date,
          link: @url,
          pmid: match[:pmid],
        }
      end

      def match
        @match ||= @url.match(%r{www\.ncbi\.nlm\.nih\.gov/pubmed/(?<pmid>[0-9]+)})
      end
    end
  end
end
