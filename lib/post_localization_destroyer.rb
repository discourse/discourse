# frozen_string_literal: true

class PostLocalizationDestroyer
  def self.destroy(post_id:, locale:, acting_user:)
    Guardian.new(acting_user).ensure_can_localize_content!

    localization = PostLocalization.find_by(post_id: post_id, locale: locale)
    raise Discourse::NotFound unless localization

    localization.destroy
  end
end
