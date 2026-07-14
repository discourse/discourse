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

  private

  def serialize_users(users)
    ActiveModel::ArraySerializer.new(users, each_serializer: FoundUserSerializer).as_json
  end

  def serialize_groups(groups)
    ActiveModel::ArraySerializer.new(groups, each_serializer: FoundGroupSerializer).as_json
  end
end
