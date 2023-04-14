# frozen_string_literal: true

DiscourseAutomation::Scriptable::SEND_PMS = "send_pms"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::SEND_PMS) do
  version 1

  placeholder :sender_username
  placeholder :receiver_username

  field :sender, component: :user
  field :receiver, component: :user, triggerable: :recurring
  field :sendable_pms, component: :pms, accepts_placeholders: true, required: true

  triggerables %i[
                 user_badge_granted
                 user_added_to_group
                 stalled_wiki
                 recurring
                 user_promoted
                 api_call
                 user_removed_from_group
               ]

  script do |context, fields, automation|
    sender_username = fields.dig("sender", "value") || Discourse.system_user.username

    placeholders = { sender_username: sender_username }.merge(context["placeholders"] || {})

    usernames = context["usernames"] || []

    # optional field when using recurring triggerable
    if u = fields.dig("receiver", "value")
      usernames << u
    end

    usernames.compact.uniq.each do |username|
      placeholders[:receiver_username] = username
      Array(fields.dig("sendable_pms", "value")).each do |sendable|
        next if !sendable["title"] || !sendable["raw"]

        pm = {}
        pm["title"] = utils.apply_placeholders(sendable["title"], placeholders)
        pm["raw"] = utils.apply_placeholders(sendable["raw"], placeholders)
        pm["target_usernames"] = Array(username)

        utils.send_pm(
          pm,
          sender: sender_username,
          automation_id: automation.id,
          delay: sendable["delay"],
          prefers_encrypt: !!sendable["prefers_encrypt"],
        )
      end
    end
  end
end
