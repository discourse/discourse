# frozen_string_literal: true

class TagLocalizationCreator
  class << self
    def create(tag:, locale:, name:, description: nil, user:)
      raise Discourse::NotFound unless tag

      Guardian.new(user).ensure_can_localize_tag!(tag)

      TagLocalization.create!(tag: tag, locale: locale, name: name, description: description)
    end
  end
end
