# frozen_string_literal: true

module DiscourseBoosts
  class BoostsController < ::ApplicationController
    requires_plugin DiscourseBoosts::PLUGIN_NAME
    before_action :ensure_logged_in, except: [:index]

    def create
      RateLimiter.new(current_user, "create_boost", 5, 1.minute).performed!

      Boost::Create.call(service_params) do |result|
        on_success do |boost:|
          render json: BoostSerializer.new(boost, scope: guardian, root: false)
        end
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_failed_policy(:can_boost_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:user_has_not_boosted_post) do
          render_json_error(I18n.t("discourse_boosts.boost_limit_reached"), status: 422)
        end
        on_failed_policy(:within_post_boost_limit) do
          render_json_error(I18n.t("discourse_boosts.post_boost_limit_reached"), status: 422)
        end
        on_failure do
          if result["result.model.boost"]&.exception.is_a?(ActiveRecord::RecordNotUnique)
            render_json_error(I18n.t("discourse_boosts.boost_limit_reached"), status: 422)
          else
            render(json: failed_json, status: :unprocessable_entity)
          end
        end
      end
    end

    def destroy
      RateLimiter.new(current_user, "destroy_boost", 5, 1.minute).performed!

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

    def flag
      RateLimiter.new(current_user, "flag_boost", 4, 1.minute).performed!

      Boost::Flag.call(service_params.deep_merge(params: { boost_id: params[:id] })) do
        on_success { render json: success_json }
        on_failed_contract do |contract|
          render json: failed_json.merge(errors: contract.errors.full_messages),
                 status: :bad_request
        end
        on_model_not_found(:boost) { raise Discourse::NotFound }
        on_failed_policy(:can_flag_boost) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_flag_again) do
          render_json_error(I18n.t("discourse_boosts.already_flagged"), status: 422)
        end
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
