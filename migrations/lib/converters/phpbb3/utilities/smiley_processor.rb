# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class SmileyProcessor
    STANDARD_SMILIES = {
      ":)" => "🙂",
      ":-))" => "🙂",
      ":-)" => "🙂",
      ";)" => "😉",
      ";-)" => "😉",
      ":D" => "😀",
      ":-D" => "😀",
      ":grin:" => "😀",
      ":(" => "😞",
      ":-(" => "😞",
      ":sad:" => "😞",
      ":o" => "😮",
      ":-o" => "😮",
      ":shock:" => "😮",
      ":?" => "😕",
      ":-?" => "😕",
      "8-)" => "😎",
      ":cool:" => "😎",
      ":lol:" => "😂",
      ":x" => "😡",
      ":-x" => "😡",
      ":mad:" => "😡",
      ":P" => "😛",
      ":-P" => "😛",
      ":razz:" => "😛",
      ":oops:" => "😳",
      ":cry:" => "😢",
      ":evil:" => "👿",
      ":twisted:" => "😈",
      ":roll:" => "🙄",
      ":wink:" => "😉",
      ":!:" => "❗",
      ":?:" => "❓",
      ":idea:" => "💡",
      ":arrow:" => "➡️",
      ":|" => "😐",
      ":-|" => "😐",
      ":neutral:" => "😐",
      ":mrgreen:" => "😀",
      ":geek:" => "🤓",
      ":ugeek:" => "🤓",
    }.freeze

    def initialize(query_provider: nil, phpbb_config: {})
      @query_provider = query_provider
      @phpbb_config = phpbb_config
      @cache = {}
    end

    def emoji(smiley_code)
      return @cache[smiley_code] if @cache.key?(smiley_code)

      emoji = find_emoji(smiley_code)
      @cache[smiley_code] = emoji
      emoji
    end

    def replace_smilies(text)
      return text if text.blank?

      STANDARD_SMILIES.each { |code, emoji| text.gsub!(Regexp.escape(code), emoji) }

      text.gsub(/<!-- s(\S+?) --><img[^>]*><!-- s\S+? -->/) do
        code = Regexp.last_match(1)
        emoji(code)
      end

      text
    end

    private

    def find_emoji(smiley_code)
      if STANDARD_SMILIES.key?(smiley_code)
        STANDARD_SMILIES[smiley_code]
      elsif @query_provider
        smiley = @query_provider.get_smiley(smiley_code)
        smiley ? smiley[:emotion] || smiley_code : smiley_code
      else
        smiley_code
      end
    end
  end
end
