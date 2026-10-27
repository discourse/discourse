# frozen_string_literal: true

module Jobs
  class UnsilenceUsers < ::Jobs::Scheduled
    every 15.minutes

    def execute(args)
      User
        .where("silenced_till IS NOT NULL AND silenced_till < now()")
        .find_each do |user|
          # An anonymous shadow's own column is never read (User#silenced_till), so
          # clearing it must not unsilence the account behind it.
          if user.main_user_record != user
            user.update_columns(silenced_till: nil)
          else
            # The batch may be stale: staff can silence the user again meanwhile.
            next if user.reload.silenced?
            UserSilencer.unsilence(user, Discourse.system_user)
          end
        end
    end
  end
end
