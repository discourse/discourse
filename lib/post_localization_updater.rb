# frozen_string_literal: true

class PostLocalizationUpdater
  def self.update(post_id:, locale:, raw:, user:)
    Guardian.new(user).ensure_can_localize_content!

    localization = PostLocalization.find_by(post_id: post_id, locale: locale)
    raise Discourse::NotFound unless localization

    post = Post.find_by(id: post_id)
    raise Discourse::NotFound unless post

    localization.raw = raw
    localization.cooked = PrettyText.cook(raw)
    localization.localizer_user_id = user.id
    localization.post_version = post.version
    localization.save!
    localization
  end
end
