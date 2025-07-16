# frozen_string_literal: true

Fabricator(:assignment_notification, from: :notification) do
  transient :group
  notification_type Notification.types[:assigned]
  post_number 1
  data do |attrs|
    {
      message:
        (
          if attrs[:group]
            "discourse_assign.assign_group_notification"
          else
            "discourse_assign.assign_notification"
          end
        ),
      display_username: attrs[:group] ? "group" : "user",
      assignment_id: rand(1..100),
    }.to_json
  end
end
