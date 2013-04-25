require_dependency 'oneboxer/handlebars_onebox'

module Oneboxer
  class GistOnebox < HandlebarsOnebox

    matcher /^https?:\/\/gist\.github\.com/
    favicon 'github.png'

    def translate_url
      m = @url.match(/gist\.github\.com\/([^\/]+\/)?(?<id>[0-9a-f]+)/mi)
      return "https://api.github.com/gists/#{m[:id]}" if m
    end

    def parse(data)
      parsed = JSON.parse(data)
      desc = parsed['description']
      if desc.length > 120
        desc = desc[0..120]
        desc << "..."
      end
      result = {files: [], title: desc}
      parsed['files'].each do |filename, attrs|
        result[:files] << {filename: filename}.merge!(attrs)
      end
      result
    end

  end
end
