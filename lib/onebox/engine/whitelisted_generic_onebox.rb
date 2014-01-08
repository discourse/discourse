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

			def	self.default_whitelist
				%w(500px.com
          about.com
          answers.com
          archive.org
          ask.com
          battle.net
          bbc.co.uk
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
          time.com
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
          wonderhowto.com
          wsj.com
          youtube.com
          zappos.com
          zillow.com)
			end
				
			def self.===(other)
				if other.kind_of?(URI)
					!!whitelist.find {|h| %r((^|\.)#{Regexp.escape(h)}$).match(other.host) }
				else
					super
				end
			end

			# Generates the HTML for the embedded content
      def photo_type?
        data[:type] =~ /photo/ || data[:type] =~ /image/
      end

			def to_html
				return data[:html] if data[:html]
        return html_for_video(data[:video]) if data[:video]
        return image_html if photo_type?
        layout.to_html
			end

			def placeholder_html
        result = nil
        result = image_html if data[:html] || data[:video] || photo_type?
				result || to_html
			end

			def data
				return raw if raw.is_a?(Hash)

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
