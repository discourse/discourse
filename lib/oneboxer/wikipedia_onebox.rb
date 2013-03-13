require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class WikipediaOnebox < HandlebarsOnebox

    matcher /^https?:\/\/.*wikipedia\.(com|org)\/.*$/
    favicon 'wikipedia.png'

    def template
      template_path('simple_onebox')
    end

    def translate_url
      m = @url.match(/^https?:\/\/((?<subdomain>.+)\.)?wikipedia\.(com|org)\/wiki\/(?<identifier>[^#\/]+)/mi)
      subdomain = m[:subdomain] || "en"
      article_id = CGI::unescape(m[:identifier])
      "http://#{subdomain}.m.wikipedia.org/w/index.php?title=#{URI::encode(article_id)}"
    end

    def parse(data)

      html_doc = Nokogiri::HTML(data)

      result = {}

      title = html_doc.at('title').inner_html
      result[:title] = title.gsub!(/ - Wikipedia.*$/, '') if title.present?

      # get the first image > 150 pix high
      images = html_doc.search("img").select { |img| img['height'].to_i > 150 }

      result[:image] = "http:#{images[0]["src"]}" unless images.empty?

      # remove the table from mobile layout, as it can contain paras in some rare cases
      html_doc.search("table").remove

      # get all the paras
      paras = html_doc.search("p")
      text = ""

      unless paras.empty?
        cnt = 0
        while text.length < MAX_TEXT && cnt <= 3
          text << " " unless cnt == 0
          paragraph = paras[cnt].inner_text[0..MAX_TEXT]
          paragraph.gsub!(/\[\d+\]/mi, "")
          text << paragraph
          cnt += 1
        end
      end

      text = "#{text[0..MAX_TEXT]}..." if text.length > MAX_TEXT
      result[:text] = text
      result
    end

  end
end
