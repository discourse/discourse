# frozen_string_literal: true

# We strip posts before detecting mentions, oneboxes, attachments etc.
# We strip those elements that shouldn't be detected. For example,
# a mention inside a quote should be ignored, so we strip it off.
class PostStripper
  def self.strip(nokogiri_fragment)
    nokogiri_fragment.css(
      "pre .mention, aside.quote > .title, aside.quote .mention, aside.quote .mention-group, .onebox, .elided",
    ).remove
    nokogiri_fragment
  end
end
