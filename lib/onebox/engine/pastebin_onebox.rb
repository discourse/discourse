module Onebox
  module Engine
    class PastebinOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^http?:\/\/pastebin\.com/)

      def paste_key
        if uri.path =~ /\/raw\//
          match = uri.path.match(/\/raw\/([^\/]+)/)
          return match[1] if match && match[1]
        elsif uri.path =~ /\/download\//
          match = uri.path.match(/\/download\/([^\/]+)/)
          return match[1] if match && match[1]
        elsif uri.path =~ /\/embed\//
          match = uri.path.match(/\/embed\/([^\/]+)/)
          return match[1] if match && match[1]
        else
          match = uri.path.match(/\/([^\/]+)/)
          return match[1] if match && match[1]
        end

        nil
      rescue
        return nil
      end

      def to_html
        return nil unless paste_key
        response = Onebox::Helpers.fetch_response("http://pastebin.com/raw/#{paste_key}", 1)
        return nil unless response && response.code.to_i == 200
        return "<iframe src='//pastebin.com/embed_iframe/#{paste_key}' style='border:none;width:100%;max-height:100px;'></iframe>"
      end
    end
  end
end
