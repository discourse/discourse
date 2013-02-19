module Oneboxer

  module Whitelist
    def self.entries
      [/^https?:\/\/(?:www\.)?cnn\.com\/.+/,
       /^https?:\/\/(?:www\.)?washingtonpost\.com\/.+/,
       /^https?:\/\/(?:www\.)?\/\d{4}\/\d{2}\/\d{2}\//,   # wordpress
       /^https?:\/\/(?:www\.)?funnyordie\.com\/.+/,
       /^https?:\/\/(?:www\.)?youtube\.com\/.+/,
       /^https?:\/\/(?:www\.)?youtu\.be\/.+/,
       /^https?:\/\/(?:www\.)?500px\.com\/.+/,
       /^https?:\/\/(?:www\.)?scribd\.com\/.+/,
       /^https?:\/\/(?:www\.)?photobucket\.com\/.+/,
       /^https?:\/\/(?:www\.)?ebay\.(com|ca|co\.uk)\/.+/,
       /^https?:\/\/(?:www\.)?nytimes\.com\/.+/,
       /^https?:\/\/(?:www\.)?tumblr\.com\/.+/,
       /^https?:\/\/(?:www\.)?pinterest\.com\/.+/,
       /^https?:\/\/(?:www\.)?imdb\.com\/.+/,
       /^https?:\/\/(?:www\.)?bbc\.co\.uk\/.+/,
       /^https?:\/\/(?:www\.)?ask\.com\/.+/,
       /^https?:\/\/(?:www\.)?huffingtonpost\.com\/.+/,
       /^https?:\/\/(?:www\.)?aol\.(com|ca)\/.+/,
       /^https?:\/\/(?:www\.)?espn\.go\.com\/.+/,
       /^https?:\/\/(?:www\.)?about\.com\/.+/,
       /^https?:\/\/(?:www\.)?cnet\.com\/.+/,
       /^https?:\/\/(?:www\.)?ehow\.com\/.+/,
       /^https?:\/\/(?:www\.)?dailymail\.co\.uk\/.+/,
       /^https?:\/\/(?:www\.)?indiatimes\.com\/.+/,
       /^https?:\/\/(?:www\.)?answers\.com\/.+/,
       /^https?:\/\/(?:www\.)?instagr\.am\/.+/,
       /^https?:\/\/(?:www\.)?battle\.net\/.+/,
       /^https?:\/\/(?:www\.)?sourceforge\.net\/.+/,
       /^https?:\/\/(?:www\.)?myspace\.com\/.+/,
       /^https?:\/\/(?:www\.)?wikia\.com\/.+/,
       /^https?:\/\/(?:www\.)?etsy\.com\/.+/,
       /^https?:\/\/(?:www\.)?walmart\.com\/.+/,
       /^https?:\/\/(?:www\.)?reference\.com\/.+/,
       /^https?:\/\/(?:www\.)?yelp\.com\/.+/,
       /^https?:\/\/(?:www\.)?foxnews\.com\/.+/,
       /^https?:\/\/(?:www\.)?guardian\.co\.uk\/.+/,
       /^https?:\/\/(?:www\.)?digg\.com\/.+/,
       /^https?:\/\/(?:www\.)?squidoo\.com\/.+/,
       /^https?:\/\/(?:www\.)?wsj\.com\/.+/,
       /^https?:\/\/(?:www\.)?archive\.org\/.+/,
       /^https?:\/\/(?:www\.)?nba\.com\/.+/,
       /^https?:\/\/(?:www\.)?samsung\.com\/.+/,
       /^https?:\/\/(?:www\.)?mashable\.com\/.+/,
       /^https?:\/\/(?:www\.)?forbes\.com\/.+/,
       /^https?:\/\/(?:www\.)?soundcloud\.com\/.+/,
       /^https?:\/\/(?:www\.)?thefreedictionary\.com\/.+/,
       /^https?:\/\/(?:www\.)?groupon\.com\/.+/,
       /^https?:\/\/(?:www\.)?ikea\.com\/.+/,
       /^https?:\/\/(?:www\.)?dell\.com\/.+/,
       /^https?:\/\/(?:www\.)?mlb\.com\/.+/,
       /^https?:\/\/(?:www\.)?bestbuy\.(com|ca)\/.+/,
       /^https?:\/\/(?:www\.)?bloomberg\.com\/.+/,
       /^https?:\/\/(?:www\.)?ign\.com\/.+/,
       /^https?:\/\/(?:www\.)?twitpic\.com\/.+/,
       /^https?:\/\/(?:www\.)?techcrunch\.com\/.+/,
       /^https?:\/\/(?:www\.)?usatoday\.com\/.+/,
       /^https?:\/\/(?:www\.)?go\.com\/.+/,
       /^https?:\/\/(?:www\.)?businessinsider\.com\/.+/,
       /^https?:\/\/(?:www\.)?zillow\.com\/.+/,
       /^https?:\/\/(?:www\.)?tmz\.com\/.+/,
       /^https?:\/\/(?:www\.)?thesun\.co\.uk\/.+/,
       /^https?:\/\/(?:www\.)?thestar\.(com|ca)\/.+/,
       /^https?:\/\/(?:www\.)?theglobeandmail\.com\/.+/,
       /^https?:\/\/(?:www\.)?torontosun\.com\/.+/,
       /^https?:\/\/(?:www\.)?kickstarter\.com\/.+/,
       /^https?:\/\/(?:www\.)?wired\.com\/.+/,
       /^https?:\/\/(?:www\.)?time\.com\/.+/,
       /^https?:\/\/(?:www\.)?npr\.org\/.+/,
       /^https?:\/\/(?:www\.)?cracked\.com\/.+/,
       /^https?:\/\/(?:www\.)?thinkgeek\.com\/.+/,
       /^https?:\/\/(?:www\.)?deadline\.com\/.+/
     ]
    end    

    def self.allowed?(url)
      #return true
      entries.each {|e| return true if url =~ e }
      false
    end

  end

end
