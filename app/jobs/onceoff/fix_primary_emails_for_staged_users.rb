# frozen_string_literal: true

module Jobs
  class FixPrimaryEmailsForStagedUsers < ::Jobs::Onceoff
    def execute_onceoff(args)
      users = User.where(active: false, staged: true).joins(:email_tokens)
      acting_user = Discourse.system_user
      destroyer = UserDestroyer.new(acting_user)

      users.group("email_tokens.email")
        .having("COUNT(email_tokens.email) > 1")
        .count
        .each_key do |email|

        query = users.where("email_tokens.email = ?", email).order(id: :asc)

        original_user = query.first

        query.offset(1).each do |user|
          user.posts.each do |post|
            post.set_owner(original_user, acting_user)
          end
          destroyer.destroy(user, context: I18n.t("user.destroy_reasons.fixed_primary_email"))
        end
      end

      DB.exec <<~SQL
      INSERT INTO user_emails (
        user_id,
        email,
        "primary",
        created_at,
        updated_at
      ) SELECT DISTINCT
        users.id,
        email_tokens.email,
        TRUE,
        users.created_at,
        users.updated_at
      FROM users
      LEFT JOIN user_emails ON user_emails.user_id = users.id
      LEFT JOIN email_tokens ON email_tokens.user_id = users.id
      WHERE staged
      AND NOT active
      AND user_emails.id IS NULL
      SQL
    end
  end
end
