# frozen_string_literal: true

class PostLocalizationCreator
  def self.create(post:, locale:, raw:, user:)
    Guardian.new(user).ensure_can_localize_post!(post)

    localization =
      PostLocalization.create!(
        post: post,
        locale: locale,
        raw: raw,
        cooked: post.post_analyzer.cook(raw, post.cooking_options || {}),
        post_version: post.version,
        localizer_user_id: user.id,
      )

    Jobs.enqueue(:process_localized_cooked, post_localization_id: localization.id)

    localization
  end
end
