# frozen_string_literal: true

DiscourseAutomation::Scriptable.add('send_pms') do
  version 1

  placeholder :sender_username
  placeholder :receiver_username

  field :sender, component: :user
  field :sendable_pms, component: :pms, accepts_placeholders: true

  triggerables %i[user_added_to_group]

  script do |trigger, fields|
    placeholders = {
      receiver_username: trigger['user'].username,
      sender_username: fields['sender']['username']
    }

    fields['sendable_pms']['pms'].each do |sendable|
      pm = {}
      pm['title'] = utils.apply_placeholders(sendable['title'], placeholders)
      pm['raw'] = utils.apply_placeholders(sendable['raw'], placeholders)
      pm['target_usernames'] = Array(trigger['user'].username)

      utils.send_pm(
        pm,
        sender: fields['sender']['username'],
        automation_id: automation.id,
        delay: sendable['delay']
      )
    end
  end
end
