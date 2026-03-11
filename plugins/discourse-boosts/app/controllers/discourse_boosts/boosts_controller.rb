# frozen_string_literal: true

module DiscourseBoosts
  class BoostsController < ::ApplicationController
    requires_plugin DiscourseBoosts::PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]

    def create
      Boost::Create.call(service_params) do
        on_success do |boost:|
          render json: BoostSerializer.new(boost, scope: guardian, root: false)
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_failed_policy(:can_boost_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:within_user_boost_limit) do
          render_json_error(I18n.t("discourse_boosts.boost_limit_reached"), status: 422)
        end
        on_failed_policy(:within_post_boost_limit) do
          render_json_error(I18n.t("discourse_boosts.post_boost_limit_reached"), status: 422)
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def destroy
      Boost::Destroy.call(service_params.deep_merge(params: { boost_id: params[:id] })) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:boost) { raise Discourse::NotFound }
        on_failed_policy(:can_destroy_boost) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def index
      Boost::List.call(service_params) do
        on_success do |boosts:|
          render json: boosts, each_serializer: BoostListSerializer, scope: guardian, root: "boosts"
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:target_user) { raise Discourse::NotFound }
        on_failed_policy(:can_see_profile) { raise Discourse::NotFound }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end
  end
end
