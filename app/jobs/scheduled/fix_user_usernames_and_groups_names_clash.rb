module Jobs
  class FixUserUsernamesAndGroupNamesClash < Jobs::Scheduled
    every 1.week

    def execute(args)
      User.joins("LEFT JOIN groups ON lower(groups.name) = users.username_lower")
        .where("groups.id IS NOT NULL")
        .find_each do |user|

        suffix = 1
        old_username = user.username

        loop do
          user.username = "#{old_username}#{suffix}"
          suffix += 1
          break if user.valid?
        end

        new_username = user.username
        user.username = old_username

        UsernameChanger.new(
          user,
          new_username
        ).change(asynchronous: false)
      end
    end
  end
end
