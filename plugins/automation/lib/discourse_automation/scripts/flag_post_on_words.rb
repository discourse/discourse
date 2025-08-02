# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::FLAG_POST_ON_WORDS) do
  field :words, component: :text_list, required: true

  version 1

  triggerables %i[post_created_edited]

  script do |trigger, fields|
    post = trigger["post"]

    Array(fields.dig("words", "value")).each do |list|
      words = list.split(",")
      count = words.inject(0) { |acc, word| post.raw.match?(/#{word}/i) ? acc + 1 : acc }
      next if count < words.length

      has_trust_level = post.user.has_trust_level?(TrustLevel[2])
      trusted_user =
        has_trust_level ||
          ReviewableFlaggedPost.where(
            status: Reviewable.statuses[:rejected],
            target_created_by: post.user,
          ).exists?
      next if trusted_user

      message =
        I18n.t("discourse_automation.scriptables.flag_post_on_words.flag_message", words: list)
      PostActionCreator.new(
        Discourse.system_user,
        post,
        PostActionType.types[:spam],
        message: message,
        queue_for_review: true,
      ).perform
    end
  end
end
