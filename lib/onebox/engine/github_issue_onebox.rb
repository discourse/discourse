# frozen_string_literal: true

module Onebox
  module Engine
    class GithubIssueOnebox
      #Author Lidlanca 2014
      include Engine
      include LayoutSupport
      include JSON
      matches_regexp Regexp.new("^https?:\/\/(?:www\.)?(?:(?:\w)+\.)?github\.com\/(?<org>.+)\/(?<repo>.+)\/issues\/([[:digit:]]+)")
      always_https

      def url
        m = match
        "https://api.github.com/repos/#{m["org"]}/#{m["repo"]}/issues/#{m["item_id"]}"
      end

      private

      def match
        @match ||= @url.match(/^http(?:s)?:\/\/(?:www\.)?(?:(?:\w)+\.)?github\.com\/(?<org>.+)\/(?<repo>.+)\/(?<type>issues)\/(?<item_id>[\d]+)/)
      end

      def data
        @raw ||= ::MultiJson.load(URI.open(url, "Accept" => "application/vnd.github.v3.text+json", read_timeout: timeout)) #custom Accept header so we can get body as text.
        body_text = @raw["body_text"]

        content_words = body_text.gsub("\n\n", "\n").gsub("\n", "<br>").split(" ") #one pass of removing double newline, then we change \n to <br> and later on we revert it back to \n this is a workaround to avoid losing newlines after we join it back.
        max_words = 20
        short_content =  content_words[0..max_words].join(" ")
        short_content += "..." if content_words.length > max_words

        created_at = Time.parse(@raw['created_at'])
        closed_at = Time.parse(@raw['closed_at']) if @raw['closed_at']

        ulink = URI(link)
        {
          link: @url,
          title: @raw["title"],
          content: short_content.gsub("<br>", "\n"),
          labels: @raw["labels"],
          user: @raw['user'],
          created_at: created_at.strftime("%I:%M%p - %d %b %y %Z"),
          created_at_date: created_at.strftime("%F"),
          created_at_time: created_at.strftime("%T"),
          closed_at: closed_at&.strftime("%I:%M%p - %d %b %y %Z"),
          closed_at_date: closed_at&.strftime("%F"),
          closed_at_time: closed_at&.strftime("%T"),
          closed_by: @raw['closed_by'],
          avatar: "https://avatars1.githubusercontent.com/u/#{@raw['user']['id']}?v=2&s=96",
          domain: "#{ulink.host}/#{ulink.path.split('/')[1]}/#{ulink.path.split('/')[2]}",
        }
      end
    end
  end
end
