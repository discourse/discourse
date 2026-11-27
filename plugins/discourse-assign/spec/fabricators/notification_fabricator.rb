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
      assignment_id: rand(1..100),
    }.tap do |data|
        if attrs[:group]
          data[:display_label] = "group"
        else
          data[:display_user_id] = (attrs[:user] || Fabricate(:user)).id
        end
      end
      .to_json
  end
end
