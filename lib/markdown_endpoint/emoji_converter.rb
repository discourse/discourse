# frozen_string_literal: true

module MarkdownEndpoint
  class EmojiConverter
    def self.convert(text)
      text
        .to_s
        .gsub(Emoji::EMOJI_CODE_REGEXP) do |shortcode|
          name, tone = Regexp.last_match(1).split(":", 2)
          Emoji.lookup_unicode([Emoji.resolve_alias(name), tone].compact.join(":")) || shortcode
        end
    end
  end
end
