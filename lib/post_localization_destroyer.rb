# frozen_string_literal: true

class PostLocalizationDestroyer
  def self.destroy(post:, locale:, acting_user:)
    Guardian.new(acting_user).ensure_can_localize_post!(post)

    localization = PostLocalization.find_by(post_id: post.id, locale:)
    raise Discourse::NotFound unless localization

    localization.destroy!
    post.publish_change_to_clients! :revised
  end
end
