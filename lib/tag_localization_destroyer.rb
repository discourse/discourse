# frozen_string_literal: true

class TagLocalizationDestroyer
  def self.destroy(tag:, locale:, acting_user:)
    raise Discourse::NotFound unless tag

    Guardian.new(acting_user).ensure_can_localize_tag!(tag)

    localization = TagLocalization.find_by(tag_id: tag.id, locale:)
    raise Discourse::NotFound unless localization

    localization.destroy!
  end
end
