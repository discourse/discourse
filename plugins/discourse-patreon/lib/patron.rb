# frozen_string_literal: true

require "json"

module ::Patreon
  class Patron
    def self.update!
      return unless Patreon::Campaign.update!
      sync_groups

      rewards = Patreon.get("rewards")
      ::MessageBus.publish "/patreon/background_sync", rewards
    end

    def self.sync_groups
      filters = Patreon.get("filters") || {}
      return if filters.blank?

      local_users = get_local_users
      reward_users = Patreon::RewardUser.all
      declined_users = Patreon::Pledge::Decline.all
      declined_pledges_grace_period_days = SiteSetting.patreon_declined_pledges_grace_period_days

      filters.each_pair do |group_id, rewards|
        group = Group.find_by(id: group_id)

        next if group.nil?

        patron_ids = rewards.map { |id| reward_users[id] }.compact.flatten.uniq

        next if patron_ids.blank?

        user_ids =
          local_users
            .select do |_, patreon_id|
              is_declined = false
              declined_since = declined_users[patreon_id]

              if declined_since.present?
                declined_days_count = Time.now.to_date - declined_since.to_date
                is_declined = declined_days_count > declined_pledges_grace_period_days
              end

              patreon_id.present? && patron_ids.include?(patreon_id) && !is_declined
            end
            .pluck(0)

        group_user_ids = GroupUser.where(group: group).pluck(:user_id)

        User.where(id: (user_ids - group_user_ids)).each { |user| group.add user }

        User.where(id: (group_user_ids - user_ids)).each { |user| group.remove user }
      end
    end

    def self.sync_groups_by(patreon_id:)
      filters = Patreon.get("filters") || {}
      return if filters.blank?

      user = get_local_user(patreon_id)
      return if user.blank?

      reward_users = Patreon::RewardUser.all
      declined_since = Patreon::Pledge::Decline.all[patreon_id]
      declined_pledges_grace_period_days = SiteSetting.patreon_declined_pledges_grace_period_days
      is_member = true

      if declined_since.present?
        declined_days_count = Time.now.to_date - declined_since.to_date
        is_member = false if declined_days_count > declined_pledges_grace_period_days
      end

      filters.each_pair do |group_id, rewards|
        group = Group.find_by(id: group_id)
        next if group.blank?

        if is_member
          patron_ids = rewards.map { |id| reward_users[id] }.compact.flatten.uniq
          next if patron_ids.blank?

          is_member = false if patron_ids.exclude?(patreon_id)
        end

        is_existing_member = GroupUser.exists?(group: group, user: user)

        if is_member && !is_existing_member
          group.add user
        elsif !is_member && is_existing_member
          group.remove user
        end
      end
    end

    def self.all
      Patreon.get("users") || {}
    end

    def self.update_local_user(user, patreon_id, skip_save = false)
      return if user.blank?

      user.custom_fields["patreon_id"] = patreon_id
      user.save_custom_fields unless skip_save || user.custom_fields_clean?

      user
    end

    def self.attr(name, user)
      id = user.custom_fields["patreon_id"]
      return if id.blank?

      case name
      when "email"
        all[id]
      when "amount_cents"
        Patreon::Pledge.all[id]
      when "rewards"
        reward_users = Patreon::RewardUser.all
        Patreon::Reward
          .all
          .map { |i, r| r["title"] if reward_users[i].include?(id) }
          .compact
          .join(", ")
      when "declined_since"
        Patreon::Pledge::Decline.all[id]
      else
        id
      end
    end

    def self.get_local_users
      users =
        User.joins(
          "INNER JOIN user_custom_fields cf ON cf.user_id = users.id AND cf.name = 'patreon_id'",
        ).pluck("users.id, cf.value")
      patrons = all.slice!(*users.pluck(1))

      oauth_users = UserAssociatedAccount.includes(:user).where(provider_name: "patreon")
      oauth_users = oauth_users.where("provider_uid IN (?)", patrons.keys) if patrons.present?

      users +=
        oauth_users.map do |o|
          patrons = patrons.slice!(o.provider_uid)
          update_local_user(o.user, o.provider_uid)
          [o.user_id, o.provider_uid]
        end

      emails = patrons.values.map { |e| e.downcase }
      users +=
        UserEmail
          .includes(:user)
          .where(email: emails)
          .map do |u|
            patreon_id = patrons.key(u.email)
            update_local_user(u.user, patreon_id)
            [u.user_id, patreon_id]
          end

      users.compact
    end

    def self.get_local_user(patreon_id)
      user =
        User.joins(:_custom_fields).find_by(
          user_custom_fields: {
            name: "patreon_id",
            value: patreon_id,
          },
        )
      return user if user.present?

      user =
        User.joins(:user_associated_accounts).find_by(
          user_associated_accounts: {
            provider_name: "patreon",
            provider_uid: patreon_id,
          },
        )
      user ||= User.joins(:user_emails).find_by(user_emails: { email: all[patreon_id] })
      return if user.blank?

      update_local_user(user, patreon_id)
    end
  end
end
