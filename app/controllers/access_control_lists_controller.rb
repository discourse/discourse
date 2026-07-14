# frozen_string_literal: true

class AccessControlListsController < ApplicationController
  requires_login

  SEARCH_GRANTEES_LIMIT = 50

  def search_grantees
    term = params[:term].to_s.strip

    if term.blank?
      render json: { users: [], groups: [] }
      return
    end

    limit = fetch_limit_from_params(default: SEARCH_GRANTEES_LIMIT, max: SEARCH_GRANTEES_LIMIT)
    users = UserSearch.new(term, searching_user: current_user, limit: limit).search
    groups = Group.search_groups(term, groups: visible_groups, sort: :auto).limit(limit)

    render json: { users: serialize_users(users), groups: serialize_groups(groups) }
  end

  private

  def visible_groups
    Group.visible_groups(
      current_user,
      "groups.name ASC",
      include_everyone: !SiteSetting.granular_anonymous_and_logged_in_groups_permissions,
      include_pseudogroups: SiteSetting.granular_anonymous_and_logged_in_groups_permissions,
    )
  end

  def serialize_users(users)
    ActiveModel::ArraySerializer.new(users, each_serializer: FoundUserSerializer).as_json
  end

  def serialize_groups(groups)
    ActiveModel::ArraySerializer.new(groups, each_serializer: FoundGroupSerializer).as_json
  end
end
