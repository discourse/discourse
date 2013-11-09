#******************************************************************************#
#                                                                              #
# Oneboxer already supports most sites using OpenGraph via the OpenGraphOnebox #
# class. If the site you want to create a onebox for supports OpenGraph,       #
# please try adding the site to the whitelist below before creating a custom   #
# parser or template.                                                          #
#                                                                              #
#******************************************************************************#

module Oneboxer
  module Whitelist
    def self.entries
      @entries ||= [
       Entry.new(/^https?:\/\/(?:www\.)?findery\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?zappos\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?slideshare\.net\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?rottentomatoes\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?cnn\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?washingtonpost\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?funnyordie\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?500px\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?scribd\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?photobucket\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?ebay\.(com|ca|co\.uk)\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?nytimes\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?pinterest\.com\/.+/),
       # Entry.new(/^https?:\/\/(?:www\.)?imdb\.com\/.+/),  # For legal reasons, we cannot include IMDB onebox support
       Entry.new(/^https?:\/\/(?:www\.)?bbc\.co\.uk\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?ask\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?huffingtonpost\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?aol\.(com|ca)\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?espn\.go\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?about\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?cnet\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?ehow\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?dailymail\.co\.uk\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?indiatimes\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?answers\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?instagr\.am\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?battle\.net\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?sourceforge\.net\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?myspace\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?wikia\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?etsy\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?walmart\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?reference\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?yelp\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?foxnews\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?guardian\.co\.uk\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?digg\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?squidoo\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?wsj\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?archive\.org\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?nba\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?samsung\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?mashable\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?forbes\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?thefreedictionary\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?groupon\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?ikea\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?dell\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?mlb\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?bestbuy\.(com|ca)\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?bloomberg\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?ign\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?twitpic\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?techcrunch\.com\/.+/, false),
       Entry.new(/^https?:\/\/(?:www\.)?usatoday\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?go\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?businessinsider\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?zillow\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?tmz\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?thesun\.co\.uk\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?thestar\.(com|ca)\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?theglobeandmail\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?torontosun\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?kickstarter\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?wired\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?time\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?npr\.org\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?cracked\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?deadline\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?thinkgeek\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?theonion\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?screenr\.com\/.+/),
       Entry.new(/^https?:\/\/(?:www\.)?tumblr\.com\/.+/, false),
       Entry.new(/^https?:\/\/(?:www\.)?howtogeek\.com\/.+/, false),
       Entry.new(/^https?:\/\/(?:www\.)?screencast\.com\/.+/),
       Entry.new(/\/\d{4}\/\d{2}\/\d{2}\//, false),   # wordpress
       Entry.new(/^https?:\/\/[^\/]+\/t\/[^\/]+\/\d+(\/\d+)?(\?.*)?$/),

       # Online learning resources
       Entry.new(/^https?:\/\/(?:www\.)?coursera\.org\/.+/, false),
       Entry.new(/^https?:\/\/(?:www\.)?khanacademy\.org\/.+/, false),
       Entry.new(/^https?:\/\/(?:www\.)?ted\.com\/talks\/.+/, false), # only /talks have meta info
       Entry.new(/^https?:\/\/(?:www\.)?wikihow\.com\/.+/, false),
       Entry.new(/^https?:\/\/(?:\w+\.)?wonderhowto\.com\/.+/, false)
      ]
    end

    def self.entry_for_url(url)
      entries.each {|e| return e if e.matches?(url) }
      nil
    end

    class Entry
      # oembed = false is probably safer, but this is the least-drastic change
      def initialize(pattern, oembed = true)
        @pattern = pattern
        @oembed = oembed
      end

      def allows_oembed?
        @oembed
      end

      def matches?(url)
        url =~ @pattern
      end
    end

  end

end
