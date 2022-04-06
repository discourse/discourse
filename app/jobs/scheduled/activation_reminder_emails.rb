# frozen_string_literal: true

module Jobs
  class ActivationReminderEmails < ::Jobs::Scheduled
    every 2.hours

    def execute(args)
      User.joins("LEFT JOIN user_custom_fields ON users.id = user_id AND user_custom_fields.name = 'activation_reminder'")
        .where(active: false, staged: false, user_custom_fields: { value: nil })
        .where('users.created_at BETWEEN ? AND ?', 3.days.ago, 2.days.ago)
        .find_each do |user|

        user.custom_fields['activation_reminder'] = true
        user.save_custom_fields

        email_token = user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
        ::Jobs.enqueue(
          :user_email,
          type: "activation_reminder",
          user_id: user.id,
          email_token: email_token.token
        )
      end
    end
  end
end
