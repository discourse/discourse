# frozen_string_literal: true

class TagLocalizationUpdater
  def self.update(tag:, locale:, name:, description: nil, user:)
    raise Discourse::NotFound unless tag

    Guardian.new(user).ensure_can_localize_tag!(tag)

    localization = TagLocalization.find_by(tag_id: tag.id, locale: locale)
    raise Discourse::NotFound unless localization

    return localization if localization.name == name && localization.description == description

    localization.name = name
    localization.description = description
    localization.save!

    localization
  end
end
