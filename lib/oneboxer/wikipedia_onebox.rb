require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class WikipediaOnebox < HandlebarsOnebox

    matcher /^https?:\/\/.*wikipedia.(com|org)\/.*$/
    favicon 'wikipedia.png'

    def template
      template_path('simple_onebox')
    end

    def translate_url
      m = @url.match(/wiki\/(?<identifier>[^#\/]+)/mi)

      article_id = CGI::unescape(m[:identifier])
      return "http://en.m.wikipedia.org/w/index.php?title=#{URI::encode(article_id)}"
      @url
    end

    def parse(data)

      hp = Hpricot(data)

      result = {}

      title = hp.at('title').inner_html
      result[:title] = title.gsub!(/ - Wikipedia, the free encyclopedia/, '') if title.present?

      # get the first image > 150 pix high
      images = hp.search("img").select { |img| img['height'].to_i > 150 }
      
      result[:image] = "http:#{images[0]["src"]}" unless images.empty?

      # remove the table from mobile layout, as it can contain paras in some rare cases
      hp.search("table").remove

      # get all the paras
      paras = hp.search("p")
      text = ""

      unless paras.empty?
        cnt = 0
        while text.length < MAX_TEXT and cnt <= 3
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
