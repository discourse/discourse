require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class GithubPullrequestOnebox < HandlebarsOnebox

    matcher /^https?:\/\/(?:www\.)?github\.com\/[^\/]+\/[^\/]+\/pull\/.+/
    favicon 'github.png'

    def translate_url
      @url.match(
        /github\.com\/(?<owner>[^\/]+)\/(?<repo>[^\/]+)\/pull\/(?<number>[^\/]+)/mi
      ) do |match|
        "https://api.github.com/repos/#{match[:owner]}/#{match[:repo]}/pulls/#{match[:number]}"
      end
    end

    def parse(data)
      result = JSON.parse(data)

      result['created_at'] =
        Time.parse(result['created_at']).strftime("%I:%M%p - %d %b %y")

      result
    end
  end
end
