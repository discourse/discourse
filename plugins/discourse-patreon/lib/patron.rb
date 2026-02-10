# frozen_string_literal: true

require "json"

module Patreon
  class Patron
    def self.update!
      return unless Patreon::Campaign.update!
      sync_groups

      ::MessageBus.publish "/patreon/background_sync", PatreonReward.to_hash
    end

    def self.filters_by_group
      PatreonGroupRewardFilter
        .includes(:patreon_reward)
        .group_by(&:group_id)
        .transform_values { |records| records.map { |r| r.patreon_reward.patreon_id } }
    end

    def self.sync_groups
      filters = filters_by_group
      return if filters.blank?

      declined_pledges_grace_period_days = SiteSetting.patreon_declined_pledges_grace_period_days

      # Pre-index local users: patreon_id -> Array of user_ids
      users_by_patreon_id =
        get_local_users.each_with_object({}) do |(user_id, patreon_id), h|
          next if patreon_id.blank?
          (h[patreon_id] ||= []) << user_id
        end

      # Precompute: reward_patreon_id -> Set of patron_patreon_ids
      reward_patron_map =
        PatreonPatronReward
          .joins(:patreon_reward, :patreon_patron)
          .pluck("patreon_rewards.patreon_id", "patreon_patrons.patreon_id")
          .each_with_object({}) do |(reward_pid, patron_pid), h|
            (h[reward_pid] ||= Set.new) << patron_pid
          end

      # Precompute: all declined patrons
      declined_patrons =
        PatreonPatron.where.not(declined_since: nil).pluck(:patreon_id, :declined_since).to_h

      # Precompute: patreon_ids past grace period (ineligible)
      today = Time.zone.today
      ineligible_patreon_ids =
        declined_patrons
          .select do |_, declined_since|
            (today - declined_since.to_date) > declined_pledges_grace_period_days
          end
          .keys
          .to_set

      filters.each_pair do |group_id, reward_patreon_ids|
        group = Group.find_by(id: group_id)
        next if group.nil?

        # Union of patron_ids across all reward tiers for this filter
        patron_ids =
          reward_patreon_ids.each_with_object(Set.new) do |rpid, set|
            set.merge(reward_patron_map[rpid]) if reward_patron_map[rpid]
          end

        # Remove ineligible (declined past grace period)
        eligible_patron_ids = patron_ids - ineligible_patreon_ids

        # Map eligible patron patreon_ids to local user_ids
        user_ids = eligible_patron_ids.flat_map { |pid| users_by_patreon_id[pid] || [] }

        group_user_ids = GroupUser.where(group: group).pluck(:user_id)

        User.where(id: (user_ids - group_user_ids)).each { |user| group.add user }

        User.where(id: (group_user_ids - user_ids)).each { |user| group.remove user }
      end
    end

    def self.sync_groups_by(patreon_id:)
      filters = filters_by_group
      return if filters.blank?

      user = get_local_user(patreon_id)
      return if user.blank?

      patron = PatreonPatron.find_by(patreon_id: patreon_id)
      declined_pledges_grace_period_days = SiteSetting.patreon_declined_pledges_grace_period_days
      is_member = true

      if patron&.declined_since.present?
        declined_days_count = Time.zone.today - patron.declined_since.to_date
        is_member = false if declined_days_count > declined_pledges_grace_period_days
      end

      # Get the reward patreon_ids this patron belongs to
      patron_reward_patreon_ids =
        if patron
          PatreonPatronReward
            .joins(:patreon_reward)
            .where(patreon_patron_id: patron.id)
            .pluck("patreon_rewards.patreon_id")
        else
          []
        end

      filters.each_pair do |group_id, reward_patreon_ids|
        group = Group.find_by(id: group_id)
        next if group.blank?

        member_of_filter = is_member && (reward_patreon_ids & patron_reward_patreon_ids).present?

        is_existing_member = GroupUser.exists?(group: group, user: user)

        if member_of_filter && !is_existing_member
          group.add user
        elsif !member_of_filter && is_existing_member
          group.remove user
        end
      end
    end

    def self.all
      PatreonPatron.where.not(email: nil).pluck(:patreon_id, :email).to_h
    end

    def self.update_local_user(user, patreon_id, skip_save = false)
      return if user.blank?

      user.custom_fields["patreon_id"] = patreon_id
      user.save_custom_fields unless skip_save || user.custom_fields_clean?

      user
    end

    def self.patron_for_user(user)
      id = user.custom_fields["patreon_id"]
      return if id.blank?
      PatreonPatron.find_by(patreon_id: id)
    end

    def self.attr(name, user, patron = :not_provided)
      id = user.custom_fields["patreon_id"]
      return if id.blank?

      patron = patron_for_user(user) if patron == :not_provided

      case name
      when "email"
        patron&.email
      when "amount_cents"
        patron&.amount_cents
      when "rewards"
        return unless patron
        patron.patreon_rewards.order(:title).pluck(:title).join(", ")
      when "declined_since"
        patron&.declined_since
      else
        id
      end
    end

    def self.get_local_users
      users =
        User.joins(
          "INNER JOIN user_custom_fields cf ON cf.user_id = users.id AND cf.name = 'patreon_id'",
        ).pluck("users.id, cf.value")

      known_patreon_ids = users.map { |_, pid| pid }
      remaining_patron_data = all.reject { |pid, _| known_patreon_ids.include?(pid) }

      oauth_users = UserAssociatedAccount.includes(:user).where(provider_name: "patreon")
      if remaining_patron_data.present?
        oauth_users = oauth_users.where(provider_uid: remaining_patron_data.keys)
      end

      oauth_users.each do |o|
        remaining_patron_data.delete(o.provider_uid)
        update_local_user(o.user, o.provider_uid)
        users << [o.user_id, o.provider_uid]
      end

      patreon_id_by_email =
        remaining_patron_data.each_with_object({}) { |(pid, email), h| h[email.downcase] = pid }
      UserEmail
        .includes(:user)
        .where(email: patreon_id_by_email.keys)
        .each do |u|
          patreon_id = patreon_id_by_email[u.email.downcase]
          next unless patreon_id
          update_local_user(u.user, patreon_id)
          users << [u.user_id, patreon_id]
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

      patron = PatreonPatron.find_by(patreon_id: patreon_id)
      if patron&.email.present?
        user ||=
          User
            .joins(:user_emails)
            .where("LOWER(user_emails.email) = ?", patron.email.downcase)
            .first
      end
      return if user.blank?

      update_local_user(user, patreon_id)
    end
  end
end
