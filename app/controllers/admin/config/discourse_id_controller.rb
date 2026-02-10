# frozen_string_literal: true

class Admin::Config::DiscourseIdController < Admin::AdminController
  def show
    render json: {
             enabled: SiteSetting.enable_discourse_id,
             configured: credentials_configured?,
             stats: {
               total_users: total_users_count,
               signups_30_days: signups_last_30_days,
               logins_30_days: logins_last_30_days,
             },
           }
  end

  def regenerate_credentials
    DiscourseId::RegenerateCredentials.call(guardian:) do
      on_success { render json: success_json }
      on_failed_policy(:credentials_configured?) do
        render json: failed_json.merge(error: I18n.t("discourse_id.errors.not_configured")),
               status: :unprocessable_entity
      end
      on_failed_step(:request_challenge) do |step|
        render json: failed_json.merge(error: step.error), status: :unprocessable_entity
      end
      on_failed_step(:regenerate_with_challenge) do |step|
        render json: failed_json.merge(error: step.error), status: :unprocessable_entity
      end
      on_failure do
        render json: failed_json.merge(error: I18n.t("discourse_id.errors.regenerate_failed")),
               status: :unprocessable_entity
      end
    end
  end

  def update_settings
    params.permit(:enabled)

    if params.key?(:enabled)
      SiteSetting.set_and_log(:enable_discourse_id, params[:enabled], current_user)
    end

    render json: success_json
  end

  private

  def credentials_configured?
    SiteSetting.discourse_id_client_id.present? && SiteSetting.discourse_id_client_secret.present?
  end

  def total_users_count
    UserAssociatedAccount.where(provider_name: "discourse_id").count
  end

  def signups_last_30_days
    UserAssociatedAccount
      .where(provider_name: "discourse_id")
      .where("created_at > ?", 30.days.ago)
      .count
  end

  def logins_last_30_days
    UserAssociatedAccount
      .where(provider_name: "discourse_id")
      .where("last_used > ?", 30.days.ago)
      .count
  end
end
