# frozen_string_literal: true

class AccessControlListsController < ApplicationController
  requires_login

  SEARCH_GRANTEES_LIMIT = AccessControlList::SearchGrantees::MAX_RESULTS

  # Used to search for _potential_ users and groups to grant access
  # to a target for an ACL. Exposes same info as public /u and
  # /g endpoints, hides groups not visible to the current user.
  def search_grantees
    limit = fetch_limit_from_params(default: SEARCH_GRANTEES_LIMIT, max: SEARCH_GRANTEES_LIMIT)

    AccessControlList::SearchGrantees.call(
      service_params.deep_merge(params: { term: params[:term], limit: }),
    ) do
      on_success do |users:, groups:|
        render json: { users: serialize_users(users), groups: serialize_groups(groups) }
      end

      on_failed_contract { |contract| render_json_error(contract.errors.full_messages) }
      on_failure { render_json_error(I18n.t("generic_error")) }
    end
  end

  def evaluate
    AccessControlList::EvaluateModification.call(service_params) do |result|
      on_success { render json: success_json.merge({ current_user_will_lose_permissions: false }) }
      on_failed_contract { |contract| render_json_error(contract.errors.full_messages) }
      on_model_not_found(:target_type_klass) { raise Discourse::InvalidParameters }
      on_failed_policy(:user_will_not_lose_permission) do |target_type_klass:|
        # NOTE: The target type class (e.g. a Kanban::Board, or Category) will need to define
        # the translation key here in server.en.yml
        render_json_error(
          I18n.t(
            "access_control_list.errors.#{target_type_klass.acl_target_key}_user_will_lose_permission",
          ),
          {
            extras: {
              current_user_will_lose_permission: true,
              loss_warning_permissions: target_type_klass.loss_warning_permissions,
            },
          },
        )
      end
      on_failed_policy(:user_will_have_permission) do
        render_json_error(
          I18n.t("access_control_list.errors.user_will_not_have_permission"),
          { extras: { current_user_will_lose_permission: true } },
        )
      end
    end
  end

  private

  def serialize_users(users)
    ActiveModel::ArraySerializer.new(users, each_serializer: FoundUserSerializer).as_json
  end

  def serialize_groups(groups)
    ActiveModel::ArraySerializer.new(groups, each_serializer: FoundGroupSerializer).as_json
  end
end
