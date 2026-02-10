# frozen_string_literal: true

module Patreon
  class Pledge
    def self.create!(pledge_data)
      save!([pledge_data], true)
    end

    def self.update!(pledge_data)
      patron_id = get_patreon_id(pledge_data)

      ActiveRecord::Base.transaction do
        # Clear stale reward assignments before re-creating via save!
        if patron_id.present?
          PatreonPatron.find_by(patreon_id: patron_id)&.patreon_patron_rewards&.delete_all
        end

        save!([pledge_data], true)
      end
    end

    def self.delete!(pledge_data)
      patron_id = get_patreon_id(pledge_data)
      PatreonPatron.find_by(patreon_id: patron_id)&.destroy if patron_id.present?
    end

    PATREON_ALLOWED_HOSTS = %w[api.patreon.com www.patreon.com].freeze

    def self.pull!(uris)
      pledges_data = []

      uris.each do |uri|
        pledge_data = Patreon::Api.get(uri)

        if pledge_data["links"] && pledge_data["links"]["next"]
          next_page_uri = pledge_data["links"]["next"]
          uris << next_page_uri if next_page_uri.present? && safe_patreon_uri?(next_page_uri)
        end

        pledges_data << pledge_data if pledge_data.present?
      end

      save!(pledges_data)
    end

    def self.safe_patreon_uri?(uri)
      return false if uri.start_with?("//")
      return true if uri.start_with?("/")
      parsed = URI.parse(uri)
      parsed.scheme == "https" && PATREON_ALLOWED_HOSTS.include?(parsed.host)
    rescue URI::InvalidURIError
      false
    end

    def self.save!(pledges_data, is_append = false)
      all_patron_data = {}
      all_reward_assignments = {}

      pledges_data.each do |pledge_data|
        new_pledges, new_declines, new_reward_users, new_users = extract(pledge_data)

        new_pledges.each do |patron_id, amount|
          all_patron_data[patron_id] ||= {}
          all_patron_data[patron_id][:amount_cents] = amount.to_i
        end

        new_users.each do |patron_id, email|
          all_patron_data[patron_id] ||= {}
          all_patron_data[patron_id][:email] = email
        end

        new_declines.each do |patron_id, declined_since|
          all_patron_data[patron_id] ||= {}
          all_patron_data[patron_id][:declined_since] = declined_since
        end

        new_reward_users.each do |reward_patreon_id, patron_ids|
          all_reward_assignments[reward_patreon_id] ||= []
          all_reward_assignments[reward_patreon_id] += patron_ids
        end
      end

      if all_patron_data.blank?
        unless is_append
          PatreonPatron.destroy_all
          PatreonPatronReward.delete_all
        end
        return
      end

      # For append mode (webhooks), merge with existing DB values so we don't
      # overwrite populated fields with nil when the payload omits them.
      # Use key? checks so explicitly-set nil values (e.g. cleared declined_since)
      # are not overwritten by stale DB values.
      if is_append
        existing = PatreonPatron.where(patreon_id: all_patron_data.keys).index_by(&:patreon_id)

        all_patron_data.each do |patreon_id, data|
          if (existing_patron = existing[patreon_id])
            data[:email] = existing_patron.email unless data.key?(:email)
            data[:amount_cents] = existing_patron.amount_cents unless data.key?(:amount_cents)
            data[:declined_since] = existing_patron.declined_since unless data.key?(:declined_since)
          end
        end
      end

      # Upsert patrons
      now = Time.zone.now
      patron_rows =
        all_patron_data.map do |patreon_id, data|
          {
            patreon_id: patreon_id,
            email: data[:email],
            amount_cents: data[:amount_cents],
            declined_since: data[:declined_since],
            created_at: now,
            updated_at: now,
          }
        end

      PatreonPatron.upsert_all(
        patron_rows,
        unique_by: :patreon_id,
        update_only: %i[email amount_cents declined_since],
      )

      # Prune stale patrons on full sync
      PatreonPatron.where.not(patreon_id: all_patron_data.keys).destroy_all unless is_append

      # Update reward assignments
      all_patron_ids = all_patron_data.keys

      # Assign all patrons to the "All Patrons" reward (patreon_id "0")
      all_reward_assignments["0"] = all_patron_ids if PatreonReward.exists?(patreon_id: "0")

      # Preload maps: patreon_id -> DB id (avoids per-loop queries)
      relevant_reward_pids = all_reward_assignments.keys
      reward_id_map =
        PatreonReward.where(patreon_id: relevant_reward_pids).pluck(:patreon_id, :id).to_h

      relevant_patron_pids = all_reward_assignments.values.flatten.uniq
      patron_id_map =
        PatreonPatron.where(patreon_id: relevant_patron_pids).pluck(:patreon_id, :id).to_h

      all_reward_assignments.each do |reward_patreon_id, patron_patreon_ids|
        reward_db_id = reward_id_map[reward_patreon_id]
        next unless reward_db_id

        patron_db_ids = patron_patreon_ids.uniq.filter_map { |pid| patron_id_map[pid] }
        next if patron_db_ids.empty?

        join_rows =
          patron_db_ids.map do |patron_db_id|
            {
              patreon_patron_id: patron_db_id,
              patreon_reward_id: reward_db_id,
              created_at: now,
              updated_at: now,
            }
          end

        PatreonPatronReward.insert_all(join_rows, unique_by: :idx_patreon_patron_rewards_unique)
      end

      # On full sync, prune orphaned reward assignments
      unless is_append
        all_reward_assignments.each do |reward_patreon_id, patron_patreon_ids|
          reward_db_id = reward_id_map[reward_patreon_id]
          next unless reward_db_id

          valid_patron_db_ids = patron_patreon_ids.uniq.filter_map { |pid| patron_id_map[pid] }
          PatreonPatronReward
            .where(patreon_reward_id: reward_db_id)
            .where.not(patreon_patron_id: valid_patron_db_ids)
            .delete_all
        end

        # Remove reward assignments for rewards not in the current sync
        stale_reward_db_ids = PatreonReward.where.not(patreon_id: relevant_reward_pids).pluck(:id)
        if stale_reward_db_ids.present?
          PatreonPatronReward.where(patreon_reward_id: stale_reward_db_ids).delete_all
        end
      end
    end

    def self.extract(pledge_data)
      pledges, declines, reward_users, users = {}, {}, {}, {}

      if pledge_data && pledge_data["data"].present?
        pledge_data["data"] = [pledge_data["data"]] unless pledge_data["data"].kind_of?(Array)

        pledge_data["data"].each do |entry|
          attrs = entry["attributes"] || {}

          if entry["type"] == "pledge"
            patron_id = entry.dig("relationships", "patron", "data", "id")
            next if patron_id.nil?

            reward_id = entry.dig("relationships", "reward", "data", "id")
            (reward_users[reward_id] ||= []) << patron_id if reward_id
            pledges[patron_id] = attrs["amount_cents"]
            declines[patron_id] = attrs["declined_since"]
          elsif entry["type"] == "member"
            patron_id = entry.dig("relationships", "user", "data", "id")
            next if patron_id.nil?

            tiers = entry.dig("relationships", "currently_entitled_tiers", "data") || []
            tiers.each { |tier| (reward_users[tier["id"]] ||= []) << patron_id if tier["id"] }
            pledges[patron_id] = attrs["pledge_amount_cents"]
            declines[patron_id] = (
              if attrs["last_charge_status"] == "Declined"
                attrs["last_charge_date"]
              else
                nil
              end
            )
          end
        end

        Array(pledge_data["included"]).each do |entry|
          case entry["type"]
          when "user"
            email = entry.dig("attributes", "email")
            users[entry["id"]] = email.downcase if email.present?
          end
        end
      end

      [pledges, declines, reward_users, users]
    end

    def self.all
      PatreonPatron.where.not(amount_cents: nil).pluck(:patreon_id, :amount_cents).to_h
    end

    def self.get_patreon_id(pledge_data)
      entry = pledge_data&.dig("data")
      return if entry.nil?
      entry = entry.first if entry.is_a?(Array)
      return if entry.nil?
      key = entry["type"] == "member" ? "user" : "patron"
      entry.dig("relationships", key, "data", "id")
    end
  end
end
