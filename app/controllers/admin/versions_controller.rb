require_dependency 'discourse_hub'
require_dependency 'version'

class Admin::VersionsController < Admin::AdminController
  def show
    if SiteSetting.discourse_org_access_key.present?
      render json: success_json.merge( latest_version: DiscourseHub.current_discourse_version, installed_version: Discourse::VERSION::STRING )
    else
      # Don't contact discourse.org
      render json: success_json.merge( latest_version: Discourse::VERSION::STRING, installed_version: Discourse::VERSION::STRING )
    end
  rescue RestClient::Forbidden
    render json: {errors: [I18n.t("discourse_hub.access_token_problem")]}
  end
end
