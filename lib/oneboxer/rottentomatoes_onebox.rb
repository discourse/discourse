require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class RottentomatoesOnebox < HandlebarsOnebox

    # keep reloaders happy
    unless defined? SYNOPSIS_MAX_TEXT
      SYNOPSIS_MAX_TEXT = 370
      ROTTEN_IMG = 'http://images.rottentomatoescdn.com/images/icons/rt.rotten.med.png'
      FRESH_IMG = 'http://images.rottentomatoescdn.com/images/icons/rt.fresh.med.png'
      POPCORN_IMG = 'http://images.rottentomatoescdn.com/images/icons/popcorn_27x31.png' 
    end

    matcher /^http:\/\/(?:www\.)?rottentomatoes\.com(\/mobile)?\/m\/.*$/
    favicon 'rottentomatoes.png'

    def http_params
      {'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_0) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.65 Safari/537.31' }
    end

    def template
      template_path('rottentomatoes_onebox')
    end

    def translate_url
      m = @url.match(/^http:\/\/(?:www\.)?rottentomatoes\.com(\/mobile)?\/m\/(?<movie>.*)$/mi)
      "http://rottentomatoes.com/mobile/m/#{m[:movie]}"
    end

    def parse(data)
      html_doc = Nokogiri::HTML(data)

      result = {}

      result[:title] = html_doc.at('h1').content
      result[:poster] = html_doc.at_css('.poster img')['src']

      synopsis = html_doc.at_css('#movieSynopsis').content.squish
      synopsis.gsub!(/\$\(function\(\).+$/, '')
      result[:synopsis] = (synopsis.length > SYNOPSIS_MAX_TEXT ? "#{synopsis[0..SYNOPSIS_MAX_TEXT]}..." : synopsis)

      result[:verdict_percentage], result[:user_percentage] = html_doc.css('.rtscores .rating .percentage span').map(&:content)
      result[:popcorn_image] = POPCORN_IMG
      if html_doc.at_css('.rtscores .rating .splat')
        result[:verdict_image] = ROTTEN_IMG
      elsif html_doc.at_css('.rtscores .rating .tomato')
        result[:verdict_image] = FRESH_IMG
      end

      result[:cast] = html_doc.css('.summary .actors a').map(&:content).join(", ")

      html_doc.css('#movieInfo .info').map(&:inner_html).each do |element|
        case
        when element.include?('Director:') then result[:director] = clean_up_info(element)
        when element.include?('Rated:') then result[:rated] = clean_up_info(element)
        when element.include?('Running Time:') then result[:running_time] = clean_up_info(element)
        when element.include?('DVD Release:')
          result[:release_date] = clean_up_info(element)
          result[:release_type] = 'DVD'
        # Only show the theater release date if there is no DVD release date
        when element.include?('Theater Release:') && !result[:release_type]
          result[:release_date] = clean_up_info(element)
          result[:release_type] = 'Theater'
        end
      end

      result.delete_if { |k, v| v.blank? }
    end

    def clean_up_info(inner_html)
      inner_html.squish.gsub(/^.*<\/span>\s*/, '')
    end

  end
end
