module Oneboxer

  module Whitelist
    def self.entries
      [/cnn\.com\/.+/,
       /washingtonpost\.com\/.+/,
       /\/\d{4}\/\d{2}\/\d{2}\//,   # wordpress
       /funnyordie\.com\/.+/,
       /youtube\.com\/.+/,
       /youtu\.be\/.+/,
       /500px\.com\/.+/,
       /scribd\.com\/.+/,
       /photobucket\.com\/.+/,
       /ebay\.(com|ca|co\.uk)\/.+/,
       /nytimes\.com\/.+/,
       /tumblr\.com\/.+/,
       /pinterest\.com\/.+/,
       /imdb\.com\/.+/,
       /bbc\.co\.uk\/.+/,
       /ask\.com\/.+/,
       /huffingtonpost\.com\/.+/,
       /aol\.(com|ca)\/.+/,
       /espn\.go\.com\/.+/,
       /about\.com\/.+/,
       /cnet\.com\/.+/,
       /ehow\.com\/.+/,
       /dailymail\.co\.uk\/.+/,
       /indiatimes\.com\/.+/,
       /answers\.com\/.+/,
       /instagr\.am\/.+/,
       /battle\.net\/.+/,
       /sourceforge\.net\/.+/,
       /myspace\.com\/.+/,
       /wikia\.com\/.+/,
       /etsy\.com\/.+/,
       /walmart\.com\/.+/,
       /reference\.com\/.+/,
       /yelp\.com\/.+/,
       /foxnews\.com\/.+/,
       /guardian\.co\.uk\/.+/,
       /digg\.com\/.+/,
       /squidoo\.com\/.+/,
       /wsj\.com\/.+/,
       /archive\.org\/.+/,
       /nba\.com\/.+/,
       /samsung\.com\/.+/,
       /mashable\.com\/.+/,
       /forbes\.com\/.+/,
       /soundcloud\.com\/.+/,
       /thefreedictionary\.com\/.+/,
       /groupon\.com\/.+/,
       /ikea\.com\/.+/,
       /dell\.com\/.+/,
       /mlb\.com\/.+/,
       /bestbuy\.(com|ca)\/.+/,
       /bloomberg\.com\/.+/,
       /ign\.com\/.+/,
       /twitpic\.com\/.+/,
       /techcrunch\.com\/.+/,
       /usatoday\.com\/.+/,
       /go\.com\/.+/,
       /businessinsider\.com\/.+/,
       /zillow\.com\/.+/,
       /tmz\.com\/.+/,
       /thesun\.co\.uk\/.+/,
       /thestar\.(com|ca)\/.+/,
       /theglobeandmail\.com\/.+/,
       /torontosun\.com\/.+/,
       /kickstarter\.com\/.+/,
       /wired\.com\/.+/,
       /time\.com\/.+/,
       /npr\.org\/.+/,
       /cracked\.com\/.+/,
       /thinkgeek\.com\/.+/,
       /deadline\.com\/.+/
     ]
    end    

    def self.allowed?(url)
      #return true
      entries.each {|e| return true if url =~ e }
      false
    end

  end

end
