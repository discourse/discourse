# frozen_string_literal: true

class DirectoryItemsController < ApplicationController
  PAGE_SIZE = 50
  before_action :set_groups_exclusion, if: -> { params[:exclude_groups].present? }

  def index
    unless SiteSetting.enable_user_directory?
      raise Discourse::InvalidAccess.new(:enable_user_directory)
    end

    period = params.require(:period)
    period_type = DirectoryItem.period_types[period.to_sym]
    raise Discourse::InvalidAccess.new(:period_type) unless period_type
    result = DirectoryItem.where(period_type: period_type).includes(user: :user_custom_fields)

    if params[:group]
      group = Group.find_by(name: params[:group])
      raise Discourse::InvalidParameters.new(:group) if group.blank?
      guardian.ensure_can_see!(group)
      guardian.ensure_can_see_group_members!(group)

      result = result.includes(user: :groups).where(users: { groups: { id: group.id } })
    else
      result = result.includes(user: :primary_group)
    end

    result = apply_exclude_groups_filter(result)

    if params[:exclude_usernames]
      result =
        result
          .references(:user)
          .where.not(users: { username: params[:exclude_usernames].split(",") })
    end

    order = params[:order] || DirectoryColumn.automatic_column_names.first
    dir = params[:asc] ? "ASC" : "DESC"
    active_directory_column_names = DirectoryColumn.active_column_names
    if active_directory_column_names.include?(order.to_sym)
      result = result.order("directory_items.#{order} #{dir}, directory_items.id")
    elsif params[:order] === "username"
      result = result.order("users.#{order} #{dir}, directory_items.id")
    else
      # Ordering by user field value
      user_field = UserField.find_by(name: params[:order])
      if user_field
        result =
          result
            .references(:user)
            .joins(
              "LEFT OUTER JOIN user_custom_fields ON user_custom_fields.user_id = users.id AND user_custom_fields.name = 'user_field_#{user_field.id}'",
            )
            .order(
              "user_custom_fields.name = 'user_field_#{user_field.id}' ASC, user_custom_fields.value #{dir}",
            )
      end
    end

    result = result.includes(:user_stat) if period_type == DirectoryItem.period_types[:all]
    page = fetch_int_from_params(:page, default: 0)

    user_ids = nil
    if params[:name].present?
      user_ids = UserSearch.new(params[:name], include_staged_users: true).search.pluck(:id)
      if user_ids.present?
        # Add the current user if we have at least one other match
        user_ids << current_user.id if current_user && result.dup.where(user_id: user_ids).exists?
        result = result.where(user_id: user_ids)
      else
        result = result.where("false")
      end
    end

    if params[:username]
      user_id = User.where(username_lower: params[:username].to_s.downcase).pick(:id)
      if user_id
        result = result.where(user_id: user_id)
      else
        result = result.where("false")
      end
    end

    limit = fetch_limit_from_params(default: PAGE_SIZE, max: PAGE_SIZE)

    result_count = result.count
    result = result.limit(limit).offset(limit * page).to_a

    more_params = params.slice(:period, :order, :asc, :group, :user_field_ids).permit!
    more_params[:page] = page + 1
    load_more_uri = URI.parse(directory_items_path(more_params))
    load_more_directory_items_json = "#{load_more_uri.path}.json?#{load_more_uri.query}"

    # Put yourself at the top of the first page
    if result.present? && current_user.present? && page == 0 && !params[:group].present?
      position = result.index { |r| r.user_id == current_user.id }

      # Don't show the record unless you're not in the top positions already
      if (position || 10) >= 10
        unless @users_in_exclude_groups&.include?(current_user.id)
          your_item = DirectoryItem.where(period_type: period_type, user_id: current_user.id).first
          result.insert(0, your_item) if your_item
        end
      end
    end

    last_updated_at = DirectoryItem.last_updated_at(period_type)

    serializer_opts = {}
    if params[:user_field_ids]
      serializer_opts[:user_custom_field_map] = {}

      user_field_ids = params[:user_field_ids]&.split("|")&.map(&:to_i)
      user_field_ids.each do |user_field_id|
        serializer_opts[:user_custom_field_map][
          "#{User::USER_FIELD_PREFIX}#{user_field_id}"
        ] = user_field_id
      end
    end

    if params[:plugin_column_ids]
      serializer_opts[:plugin_column_ids] = params[:plugin_column_ids]&.split("|")&.map(&:to_i)
    end

    serializer_opts[:attributes] = active_directory_column_names
    serializer_opts[:searchable_fields] = UserField.where(searchable: true) if serializer_opts[
      :user_custom_field_map
    ].present?

    serialized = serialize_data(result, DirectoryItemSerializer, serializer_opts)
    render_json_dump(
      directory_items: serialized,
      meta: {
        last_updated_at: last_updated_at,
        total_rows_directory_items: result_count,
        load_more_directory_items: load_more_directory_items_json,
      },
    )
  end

  private

  def set_groups_exclusion
    @exclude_group_names = params[:exclude_groups].split("|")
    @exclude_group_ids = Group.where(name: @exclude_group_names).pluck(:id)
    @users_in_exclude_groups = GroupUser.where(group_id: @exclude_group_ids).pluck(:user_id)
  end

  def apply_exclude_groups_filter(result)
    result = result.where.not(user_id: @users_in_exclude_groups) if params[:exclude_groups]
    result
  end
end
