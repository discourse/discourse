# frozen_string_literal: true

class Patreon::PatreonAdminController < Admin::AdminController
  requires_plugin Patreon::PLUGIN_NAME

  before_action :patreon_enabled?
  before_action :patreon_tokens_present?

  def patreon_enabled?
    raise Discourse::NotFound unless SiteSetting.patreon_enabled
  end

  def list
    filters =
      PatreonGroupRewardFilter
        .includes(:patreon_reward)
        .group_by(&:group_id)
        .transform_values { |records| records.map { |r| r.patreon_reward.patreon_id } }

    last_sync_at = PatreonSyncLog.maximum(:synced_at)

    render json: { filters: filters, rewards: serialize_rewards, last_sync_at: last_sync_at }
  end

  def rewards
    render json: serialize_rewards
  end

  def edit
    group = find_group
    return if group.nil?

    if params[:rewards_ids].nil?
      return(
        render json: failed_json.merge(message: I18n.t("patreon.error.missing_rewards")),
               status: :unprocessable_entity
      )
    end

    reward_patreon_ids = Array(params[:rewards_ids]).map(&:to_s).uniq
    rewards = PatreonReward.where(patreon_id: reward_patreon_ids).index_by(&:patreon_id)
    unknown_ids = reward_patreon_ids - rewards.keys

    if unknown_ids.present?
      return(
        render json:
                 failed_json.merge(
                   message: I18n.t("patreon.error.unknown_rewards", ids: unknown_ids.join(", ")),
                 ),
               status: :unprocessable_entity
      )
    end

    ActiveRecord::Base.transaction do
      PatreonGroupRewardFilter.where(group: group).destroy_all

      rewards.each_value do |reward|
        PatreonGroupRewardFilter.create!(group: group, patreon_reward: reward)
      end
    end

    render json: success_json
  end

  def delete
    group = find_group
    return if group.nil?

    PatreonGroupRewardFilter.where(group: group).destroy_all

    render json: success_json
  end

  def sync_groups
    Patreon::Patron.sync_groups
    render json: success_json
  rescue StandardError => e
    Rails.logger.error("Patreon group sync failed: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: failed_json.merge(message: I18n.t("patreon.error.sync_failed")),
           status: :unprocessable_entity
  end

  def update_data
    Jobs.enqueue(:patreon_sync_patrons_to_groups)
    render json: success_json
  end

  def email
    user = fetch_user_from_params(include_inactive: true)

    unless user == current_user
      guardian.ensure_can_check_emails!(user)
      StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])
    end

    render json: { email: Patreon::Patron.attr("email", user) }
  end

  private

  def patreon_tokens_present?
    if SiteSetting.patreon_creator_access_token.blank?
      raise Discourse::SiteSettingMissing.new("patreon_creator_access_token")
    end
    if SiteSetting.patreon_creator_refresh_token.blank?
      raise Discourse::SiteSettingMissing.new("patreon_creator_refresh_token")
    end
  end

  def serialize_rewards
    PatreonReward.to_hash
  end

  def find_group
    group = Group.find_by(id: params[:group_id])
    if group.nil?
      render json: failed_json.merge(message: I18n.t("patreon.error.group_not_found")),
             status: :not_found
    end
    group
  end
end
