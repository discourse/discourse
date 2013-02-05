require_dependency 'mothership'
require_dependency 'version'

class Admin::VersionsController < Admin::AdminController
  def show
    if SiteSetting.discourse_org_access_key.present?
      render json: success_json.merge( latest_version: Mothership.current_discourse_version, installed_version: Discourse::VERSION::STRING )
    else
      # Don't contact discourse.org
      render json: success_json.merge( latest_version: Discourse::VERSION::STRING, installed_version: Discourse::VERSION::STRING )
    end
  rescue RestClient::Forbidden
    render json: {errors: [I18n.t("mothership.access_token_problem")]}
  end
end