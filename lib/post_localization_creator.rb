# frozen_string_literal: true

class PostLocalizationCreator
  def self.create(post_id:, locale:, raw:, user:)
    Guardian.new(user).ensure_can_localize_content!

    post = Post.find_by(id: post_id)
    raise Discourse::NotFound unless post

    PostLocalization.create!(
      post_id: post.id,
      post_version: post.version,
      locale: locale,
      raw: raw,
      cooked: PrettyText.cook(raw),
      localizer_user_id: user.id,
    )
  end
end
