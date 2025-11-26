# frozen_string_literal: true

class PostLocalizationDestroyer
  def self.destroy(post_id:, locale:, acting_user:)
    Guardian.new(acting_user).ensure_can_localize_post!(post_id)

    localization = PostLocalization.find_by(post_id:, locale:)
    raise Discourse::NotFound unless localization

    localization.destroy!

    post = localization.post
    post.publish_change_to_clients! :revised if post
  end
end
