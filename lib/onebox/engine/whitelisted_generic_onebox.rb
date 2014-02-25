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
        %w(500px.com
          about.com
          answers.com
          ask.com
          battle.net
          bbc.co.uk
          bbs.boingboing.net
          bestbuy.ca
          bestbuy.com
          blip.tv
          bloomberg.com
          businessinsider.com
          clikthrough.com
          cnet.com
          cnn.com
          collegehumor.com
          coursera.org
          cracked.com
          dailymail.co.uk
          dailymotion.com
          deadline.com
          dell.com
          digg.com
          dotsub.com
          ebay.ca
          ebay.co.uk
          ebay.com
          ehow.com
          espn.go.com
          etsy.com
          findery.com
          flickr.com
          forbes.com
          foxnews.com
          funnyordie.com
          groupon.com
          howtogeek.com
          huffingtonpost.com
          huffingtonpost.ca
          hulu.com
          ign.com
          ikea.com
          imgur.com
          indiatimes.com
          instagr.am
          instagram.com
          itunes.apple.com
          khanacademy.org
          kickstarter.com
          kinomap.com
          mashable.com
          mlb.com
          myspace.com
          nba.com
          npr.org
          photobucket.com
          pinterest.com
          reference.com
          revision3.com
          rottentomatoes.com
          samsung.com
          screenr.com
          scribd.com
          slideshare.net
          soundcloud.com
          sourceforge.net
          spotify.com
          squidoo.com
          techcrunch.com
          ted.com
          thefreedictionary.com
          theglobeandmail.com
          theonion.com
          thestar.com
          thesun.co.uk
          thinkgeek.com
          tmz.com
          torontosun.com
          tumblr.com
          twitpic.com
          usatoday.com
          vimeo.com
          walmart.com
          washingtonpost.com
          wikia.com
          wikihow.com
          wired.com
          wistia.com
          wi.st
          wonderhowto.com
          wsj.com
          zappos.com
          zillow.com)
      end

      # A re-written URL coverts https:// -> // - it is useful on HTTPS sites that embed
      # youtube for example
      def self.rewrites
        @rewrites ||= default_rewrites.dup
      end

      def self.rewrites=(new_list)
        @rewrites = new_list
      end

      def self.default_rewrites
        %w(slideshare.net)
      end

      def self.host_matches(uri, list)
        !!list.find {|h| %r((^|\.)#{Regexp.escape(h)}$).match(uri.host) }
      end

      def self.probable_discourse(uri)
        !!(uri.path =~ /\/t\/[^\/]+\/\d+(\/\d+)?(\?.*)?$/)
      end

      def self.probable_wordpress(uri)
        !!(uri.path =~ /\d{4}\/\d{2}\/\d{2}/)
      end

      def self.===(other)
        if other.kind_of?(URI)
          return WhitelistedGenericOnebox.host_matches(other, WhitelistedGenericOnebox.whitelist) ||
                 WhitelistedGenericOnebox.probable_wordpress(other) ||
                 WhitelistedGenericOnebox.probable_discourse(other)
        else
          super
        end
      end

      # Generates the HTML for the embedded content
      def photo_type?
        data[:type] =~ /photo/ || data[:type] =~ /image/
      end

      def article_type?
        data[:type] == "article"
      end

      def rewrite_agnostic(html)
        return html unless html
        uri = URI(@url)
        if WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.rewrites)
          html.gsub!(/https?:\/\//, '//')
        end
        html
      end

      def generic_html
        return data[:html] if data[:html] && data[:html] =~ /iframe/
        return layout.to_html if article_type?
        return html_for_video(data[:video]) if data[:video]
        return image_html if photo_type?
        return nil unless data[:title]
        layout.to_html
      end

      def to_html
        rewrite_agnostic(generic_html)
      end

      def placeholder_html
        result = nil
        return to_html if article_type?
        result = image_html if (data[:html] && data[:html] =~ /iframe/) || data[:video] || photo_type?
        result || to_html
      end

      def data
        if raw.is_a?(Hash)
          raw[:link] ||= link
          return raw
        end

        data_hash = { link: link, title: raw.title, description: raw.description }
        data_hash[:image] = raw.images.first if raw.images && raw.images.first
        data_hash[:type] = raw.type if raw.type

        if raw.metadata && raw.metadata[:video] && raw.metadata[:video].first
          data_hash[:video] = raw.metadata[:video].first
        end

        data_hash
      end

      private

      def image_html
        return @image_html if @image_html

        return @image_html = "<img src=\"#{data[:image]}\">" if data[:image]

        if data[:thumbnail_url]
          @image_html = "<img src=\"#{data[:thumbnail_url]}\""
          @image_html << " width=\"#{data[:thumbnail_width]}\"" if data[:thumbnail_width]
          @image_html << " height=\"#{data[:thumbnail_height]}\"" if data[:thumbnail_height]
          @image_html << ">"
        end

        @image_html
      end

      def html_for_video(video)
        video_url = video[:_value]

        if video_url
          html = "<iframe src=\"#{video_url}\" frameborder=\"0\" title=\"#{data[:title]}\""

          append_attribute(:width, html, video)
          append_attribute(:height, html, video)

          html << "></iframe>"
          return html
        end
      end

      def append_attribute(attribute, html, video)
        if video[attribute] && video[attribute].first
          val = video[attribute].first[:_value]
          html << " #{attribute.to_s}=\"#{val}\""
        end
      end
    end
  end
end
