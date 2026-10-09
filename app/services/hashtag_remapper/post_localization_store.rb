# frozen_string_literal: true

class HashtagRemapper
  class PostLocalizationStore < Store
    def self.key = "post_localization"
    def self.relation = PostLocalization.all
    def self.raw_column = :raw
    def self.cooked(localization) = localization.cooked

    def self.write!(localization, raw)
      localization.raw = raw
      localization.cooked = PrettyText.cook(raw)
      localization.save!(validate: false)
      Jobs.enqueue(:process_localized_cooked, post_localization_id: localization.id)
    end
  end
end
