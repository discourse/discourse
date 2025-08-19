# frozen_string_literal: true

require_dependency "application_controller"

class ::Patreon::PatreonAdminController < Admin::AdminController
  PLUGIN_NAME = "discourse-patreon".freeze

  requires_plugin PLUGIN_NAME

  before_action :patreon_enabled?
  before_action :patreon_tokens_present?

  def patreon_enabled?
    raise Discourse::NotFound unless SiteSetting.patreon_enabled
  end

  def list
    filters = PluginStore.get(PLUGIN_NAME, "filters") || {}
    rewards = ::Patreon::Reward.all
    last_sync = ::Patreon.get("last_sync") || {}

    groups = ::Group.all.pluck(:id)

    valid_filters = filters.select { |k| groups.include?(k.to_i) }

    render json: { filters: valid_filters, rewards: rewards, last_sync_at: last_sync["at"] }
  end

  def rewards
    rewards = ::Patreon::Reward.all

    render json: rewards
  end

  def is_number?(string)
    begin
      true if Float(string)
    rescue StandardError
      false
    end
  end

  def edit
    if params[:rewards_ids].nil? || !is_number?(params[:group_id])
      return render json: { message: "Error" }, status: 500
    end

    filters = PluginStore.get(PLUGIN_NAME, "filters") || {}

    filters[params[:group_id]] = params[:rewards_ids]

    PluginStore.set(PLUGIN_NAME, "filters", filters)

    render json: success_json
  end

  def delete
    return render json: { message: "Error" }, status: 500 unless is_number?(params[:group_id])

    filters = PluginStore.get(PLUGIN_NAME, "filters")

    filters.delete(params[:group_id])

    PluginStore.set(PLUGIN_NAME, "filters", filters)

    render json: success_json
  end

  def sync_groups
    begin
      Patreon::Patron.sync_groups
      render json: success_json
    rescue => e
      render json: { message: e.message }, status: 500
    end
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

    render json: { email: ::Patreon::Patron.attr("email", user) }
  end

  def patreon_tokens_present?
    if SiteSetting.patreon_creator_access_token.blank?
      raise Discourse::SiteSettingMissing.new("patreon_creator_access_token")
    end
    if SiteSetting.patreon_creator_refresh_token.blank?
      raise Discourse::SiteSettingMissing.new("patreon_creator_refresh_token")
    end
  end
end
