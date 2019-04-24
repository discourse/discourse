require 'htmlentities'

module Onebox
  module Engine
    class WhitelistedGenericOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      def self.whitelist=(list)
        @whitelist = list
      end

      def self.whitelist
        @whitelist ||= default_whitelist.dup
      end

      def self.default_whitelist
        %w(
          23hq.com
          500px.com
          8tracks.com
          abc.net.au
          about.com
          answers.com
          arstechnica.com
          ask.com
          battle.net
          bbc.co.uk
          bbs.boingboing.net
          bestbuy.ca
          bestbuy.com
          blip.tv
          bloomberg.com
          businessinsider.com
          change.org
          clikthrough.com
          cnet.com
          cnn.com
          codepen.io
          collegehumor.com
          consider.it
          coursera.org
          cracked.com
          dailymail.co.uk
          dailymotion.com
          deadline.com
          dell.com
          deviantart.com
          digg.com
          dotsub.com
          ebay.ca
          ebay.co.uk
          ebay.com
          ehow.com
          espn.go.com
          etsy.com
          findery.com
          folksy.com
          forbes.com
          foxnews.com
          funnyordie.com
          gifs.com
          groupon.com
          howtogeek.com
          huffingtonpost.ca
          huffingtonpost.com
          hulu.com
          ign.com
          ikea.com
          imdb.com
          indiatimes.com
          itunes.apple.com
          khanacademy.org
          kickstarter.com
          kinomap.com
          lessonplanet.com
          liveleak.com
          livestream.com
          mashable.com
          medium.com
          meetup.com
          mixcloud.com
          mlb.com
          myshopify.com
          myspace.com
          nba.com
          npr.org
          nytimes.com
          photobucket.com
          pinterest.com
          reference.com
          revision3.com
          rottentomatoes.com
          samsung.com
          screenr.com
          scribd.com
          simplecast.com
          slideshare.net
          sourceforge.net
          speakerdeck.com
          spotify.com
          squidoo.com
          streamable.com
          techcrunch.com
          ted.com
          thefreedictionary.com
          theglobeandmail.com
          thenextweb.com
          theonion.com
          thestar.com
          thesun.co.uk
          thinkgeek.com
          tmz.com
          torontosun.com
          tumblr.com
          twitpic.com
          usatoday.com
          viddler.com
          videojug.com
          vine.co
          walmart.com
          washingtonpost.com
          wi.st
          wikia.com
          wikihow.com
          wired.com
          wistia.com
          wonderhowto.com
          wsj.com
          zappos.com
          zillow.com
        )
      end

      # Often using the `html` attribute is not what we want, like for some blogs that
      # include the entire page HTML. However for some providers like Flickr it allows us
      # to return gifv and galleries.
      def self.default_html_providers
        ['Flickr', 'Meetup']
      end

      def self.html_providers
        @html_providers ||= default_html_providers.dup
      end

      def self.html_providers=(new_provs)
        @html_providers = new_provs
      end

      # A re-written URL converts http:// -> https://
      def self.rewrites
        @rewrites ||= https_hosts.dup
      end

      def self.rewrites=(new_list)
        @rewrites = new_list
      end

      def self.https_hosts
        %w(slideshare.net dailymotion.com livestream.com imgur.com flickr.com)
      end

      def self.host_matches(uri, list)
        !!list.find { |h| %r((^|\.)#{Regexp.escape(h)}$).match(uri.host) }
      end

      def self.probable_discourse(uri)
        !!(uri.path =~ /\/t\/[^\/]+\/\d+(\/\d+)?(\?.*)?$/)
      end

      def self.probable_wordpress(uri)
        !!(uri.path =~ /\d{4}\/\d{2}\//)
      end

      def self.twitter_label_whitelist
        ['brand', 'price', 'usd', 'cad', 'reading time', 'likes']
      end

      def self.===(other)
        other.kind_of?(URI) ?
          host_matches(other, whitelist) || probable_wordpress(other) || probable_discourse(other) :
          super
      end

      def to_html
        rewrite_https(generic_html)
      end

      def placeholder_html
        return article_html if is_article?
        return image_html   if has_image? && (is_video? || is_image?)
        return article_html if has_text? && is_embedded?
        to_html
      end

      def data
        @data ||= begin
          html_entities = HTMLEntities.new
          d = { link: link }.merge(raw)

          if !Onebox::Helpers.blank?(d[:title])
            d[:title] = html_entities.decode(Onebox::Helpers.truncate(d[:title], 80))
          end

          d[:description] ||= d[:summary]
          if !Onebox::Helpers.blank?(d[:description])
            d[:description] = html_entities.decode(Onebox::Helpers.truncate(d[:description], 250))
          end

          if !Onebox::Helpers.blank?(d[:site_name])
            d[:domain] = html_entities.decode(Onebox::Helpers.truncate(d[:site_name], 80))
          elsif !Onebox::Helpers.blank?(d[:domain])
            d[:domain] = "http://#{d[:domain]}" unless d[:domain] =~ /^https?:\/\//
            d[:domain] = URI(d[:domain]).host.to_s.sub(/^www\./, '') rescue nil
          end

          # prefer secure URLs
          d[:image] = d[:image_secure_url] || d[:image_url] || d[:thumbnail_url] || d[:image]
          d[:image] = Onebox::Helpers::get_absolute_image_url(d[:image], @url)

          d[:video] = d[:video_secure_url] || d[:video_url] || d[:video]

          d[:published_time] = d[:article_published_time] unless Onebox::Helpers.blank?(d[:article_published_time])
          if !Onebox::Helpers.blank?(d[:published_time])
            d[:article_published_time] = Time.parse(d[:published_time]).strftime("%-d %b %y")
            d[:article_published_time_title] = Time.parse(d[:published_time]).strftime("%I:%M%p - %d %B %Y")
          end

          # Twitter labels
          if !Onebox::Helpers.blank?(d[:label1]) && !Onebox::Helpers.blank?(d[:data1]) && !!WhitelistedGenericOnebox.twitter_label_whitelist.find { |l| d[:label1] =~ /#{l}/i }
            d[:label_1] = Onebox::Helpers.truncate(d[:label1])
            d[:data_1]  = Onebox::Helpers.truncate(d[:data1])
          end
          if !Onebox::Helpers.blank?(d[:label2]) && !Onebox::Helpers.blank?(d[:data2]) && !!WhitelistedGenericOnebox.twitter_label_whitelist.find { |l| d[:label2] =~ /#{l}/i }
            unless Onebox::Helpers.blank?(d[:label_1])
              d[:label_2] = Onebox::Helpers.truncate(d[:label2])
              d[:data_2]  = Onebox::Helpers.truncate(d[:data2])
            else
              d[:label_1] = Onebox::Helpers.truncate(d[:label2])
              d[:data_1]  = Onebox::Helpers.truncate(d[:data2])
            end
          end

          if Onebox::Helpers.blank?(d[:label_1]) && !Onebox::Helpers.blank?(d[:price_amount]) && !Onebox::Helpers.blank?(d[:price_currency])
            d[:label_1] = "Price"
            d[:data_1] = Onebox::Helpers.truncate("#{d[:price_currency].strip} #{d[:price_amount].strip}")
          end

          d
        end
      end

      private

      def rewrite_https(html)
        return unless html
        uri = URI(@url)
        html.gsub!("http://", "https://") if WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.rewrites)
        html
      end

      def generic_html
        return card_html     if is_card?
        return article_html  if is_article?
        return video_html    if is_video?
        return image_html    if is_image?
        return embedded_html if is_embedded?
        return article_html  if has_text?
      end

      def is_card?
        data[:card] == 'player' && data[:player] =~ URI::regexp
      end

      def is_article?
        (data[:type] =~ /article/ || data[:asset_type] =~ /article/) &&
        has_text?
      end

      def has_text?
        !Onebox::Helpers.blank?(data[:title]) &&
        !Onebox::Helpers.blank?(data[:description])
      end

      def is_image?
        data[:type] =~ /photo|image/ &&
        data[:type] !~ /photostream/ &&
        has_image?
      end

      def has_image?
        !Onebox::Helpers.blank?(data[:image])
      end

      def is_video?
        data[:type] =~ /^video[\/\.]/ && !Onebox::Helpers.blank?(data[:video])
      end

      def is_embedded?
        data[:html] &&
        data[:height] &&
        (
          data[:html]["iframe"] ||
          WhitelistedGenericOnebox.html_providers.include?(data[:provider_name])
        )
      end

      def card_html
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(data[:player])

        <<~RAW
        <iframe src="#{escaped_url}"
                width="#{data[:player_width] || "100%"}"
                height="#{data[:player_height]}"
                scrolling="no"
                frameborder="0">
        </iframe>
        RAW
      end

      def article_html
        layout.to_html
      end

      def image_html
        return if Onebox::Helpers.blank?(data[:image])

        escaped_src = ::Onebox::Helpers.normalize_url_for_output(data[:image])

        alt    = data[:description]  || data[:title]
        width  = data[:image_width]  || data[:thumbnail_width]  || data[:width]
        height = data[:image_height] || data[:thumbnail_height] || data[:height]

        "<img src='#{escaped_src}' alt='#{alt}' width='#{width}' height='#{height}' class='onebox'>"
      end

      def video_html
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(data[:video])

        <<-HTML
            <video title='#{data[:title]}'
                   width='#{data[:video_width]}'
                   height='#{data[:video_height]}'
                   style='max-width:100%'
                   controls='' poster='#{data[:image]}'>
              <source src='#{escaped_src}'>
            </video>
          HTML
      end

      def embedded_html
        fragment = Nokogiri::HTML::fragment(data[:html])
        fragment.css("img").each { |img| img["class"] = "thumbnail" }
        if iframe = fragment.at_css("iframe")
          iframe.remove_attribute("style")
          iframe["width"] = data[:width] || "100%"
          iframe["height"] = data[:height]
          iframe["scrolling"] = "no"
          iframe["frameborder"] = "0"
        end
        fragment.to_html
      end
    end
  end
end
