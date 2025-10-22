# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostDetectionText
      NECESSARY_REMOVAL_SELECTORS = [
        ".lightbox-wrapper", # image captions
        "blockquote, aside.quote", # quotes
      ]
      OPTIONAL_SELECTORS = [
        "a.hashtag-cooked", # categories or tags are usually in site's language
        "a.mention", # mentions are based on the mentioned's user's name
        "aside.onebox", # onebox external content
        "img.emoji",
        "code, pre",
      ]

      def self.get_text(post)
        return if post.blank?
        cooked = post.cooked
        return if cooked.blank?

        doc = Nokogiri::HTML5.fragment(cooked)
        original = doc.text.strip

        # these selectors should be removed,
        # as they are the usual culprits for incorrect detection
        doc.css(*NECESSARY_REMOVAL_SELECTORS).remove
        necessary = doc.text.strip

        doc.css(*OPTIONAL_SELECTORS).remove
        preferred = doc.text.strip

        return preferred if preferred.present?
        return necessary if necessary.present?
        original
      end
    end
  end
end
