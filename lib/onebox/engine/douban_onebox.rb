module Onebox
  module Engine
    class DoubanOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches_regexp(/^(https?:\/\/)?([\da-z\.-]+)(douban.com\/)(.)+\/?$/)

      private

        def data
          {
            link: link,
            title: raw.css('title').text.gsub("\n",'').strip(),
            image: raw.css('img[rel*="v:"]').first['src'],
            description: raw.css('meta[name=description]').first['content'],
          }
        end

    end
  end
end
