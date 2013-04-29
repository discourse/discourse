require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class RottentomatoesOnebox < HandlebarsOnebox

    API_KEY = 's8a4xfvekj7bdbd675d3qpem' 
    SYNOPSIS_MAX_TEXT = 450
    ROTTEN_IMG = 'http://images.rottentomatoescdn.com/images/icons/rt.rotten.med.png'
    FRESH_IMG = 'http://images.rottentomatoescdn.com/images/icons/rt.fresh.med.png'
    POPCORN_IMG = 'http://images.rottentomatoescdn.com/images/icons/popcorn_27x31.png' 

    matcher /^http:\/\/(?:www\.)?rottentomatoes\.com(\/mobile)?\/m\/.*$/
    favicon 'rottentomatoes.png'

    def template
      template_path('rottentomatoes_onebox')
    end

    def translate_url
      m = @url.match(/^http:\/\/(?:www\.)?rottentomatoes\.com(\/mobile)?\/m\/(?<movie>.*)$/mi)
      query = URI::escape(m[:movie].gsub(/[\/_]/, " "))
      "http://api.rottentomatoes.com/api/public/v1.0/movies.json?apikey=#{API_KEY}&q=#{query}&page_limit=1&page=1"
    end

    def parse(data)
      result = (JSON.parse(data))['movies'][0]

      result['poster'] = result['posters']['profile']
      result['cast'] = result['abridged_cast'][0..2].map{ |c| c['name'] }.join(", ")
      result['synopsis'] = "#{result['synopsis'][0..SYNOPSIS_MAX_TEXT]}..." if result['synopsis'].length > SYNOPSIS_MAX_TEXT
      
      if result['release_dates'].has_key?('dvd')
        result['release_type'] = 'DVD'
        result['release_date'] = result['release_dates']['dvd'].to_date.strftime('%b %d, %Y')
      elsif result['release_dates'].has_key?('theater')
        result['release_type'] = 'Theater'
        result['release_date'] = result['release_dates']['theater'].to_date.strftime('%b %d, %Y')
      end

      result['user_percentage'] = result['ratings']['audience_score'] if result['ratings']['audience_score'] > 0
      result['popcorn_image'] = POPCORN_IMG

      result['verdict_percentage'] = result['ratings']['critics_score']
      if result['ratings']['critics_rating'] && result['ratings']['critics_rating'].include?('Fresh')
        result['verdict_image'] = FRESH_IMG
      elsif result['ratings']['critics_rating'] && result['ratings']['critics_rating'].include?('Rotten')
        result['verdict_image'] = ROTTEN_IMG
      end
      
      result.delete_if { |k, v| v.blank? }
    end

  end
end
