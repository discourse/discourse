# frozen_string_literal: true

class PostLocalizationUpdater
  def self.update(post_id:, locale:, raw:, user:)
    Guardian.new(user).ensure_can_localize_post!(post_id)

    localization = PostLocalization.find_by(post_id: post_id, locale: locale)
    raise Discourse::NotFound unless localization
    post = localization.post
    raise Discourse::NotFound unless post

    return localization if localization.raw == raw

    localization.raw = raw
    localization.cooked = PrettyText.cook(raw)
    localization.localizer_user_id = user.id
    localization.post_version = post.version
    localization.save!

    Jobs.enqueue(:process_localized_cooked, post_localization_id: localization.id)

    localization
  end
end
