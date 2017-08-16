module Jobs
  class FixPrimaryEmailsForStagedUsers < Jobs::Onceoff
    def execute_onceoff(args)
      users = User.where(active: false, staged: true).joins(:email_tokens)
      destroyer = UserDestroyer.new(Discourse.system_user)

      users.group("email_tokens.email")
        .having("COUNT(email_tokens.email) > 1")
        .count
        .each_key do |email|

        users.where("email_tokens.email = ?", email)
          .order(id: :asc)
          .offset(1)
          .each do |user|

          destroyer.destroy(user)
        end
      end

      User.exec_sql <<~SQL
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
