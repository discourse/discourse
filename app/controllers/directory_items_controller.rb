# frozen_string_literal: true

class DirectoryItemsController < ApplicationController
  PAGE_SIZE = DirectoryItemsQuery::PAGE_SIZE
  PAGE_LIMIT = DirectoryItemsQuery::PAGE_LIMIT

  def index
    discourse_expires_in 1.minute

    unless SiteSetting.enable_user_directory?
      raise Discourse::InvalidAccess.new(:enable_user_directory)
    end

    period = params.require(:period)
    period_type = DirectoryItem.period_types[period.to_sym]
    raise Discourse::InvalidAccess.new(:period_type) unless period_type
    page = fetch_int_from_params(:page, default: 0, max: PAGE_LIMIT)
    limit = fetch_limit_from_params(default: PAGE_SIZE, max: PAGE_SIZE)
    begin
      query_result =
        DirectoryItemsQuery.new(user: current_user, guardian:).call(
          period_type:,
          group_name: params[:group],
          exclude_group_names: params[:exclude_groups]&.split("|"),
          exclude_usernames: params[:exclude_usernames]&.split(","),
          order: params[:order],
          ascending: params[:asc].present?,
          name: params[:name],
          username: params[:username],
          page:,
          limit:,
          prioritize_user: true,
        )
    rescue DirectoryItemsQuery::GroupNotFound
      raise Discourse::InvalidParameters.new(:group)
    end

    more_params = params.slice(:period, :order, :asc, :group, :user_field_ids, :name).permit!
    more_params[:page] = page + 1
    load_more_uri = URI.parse(directory_items_path(more_params))
    load_more_directory_items_json = "#{load_more_uri.path}.json?#{load_more_uri.query}"

    serializer_opts = {}
    if params[:user_field_ids]
      serializer_opts[:user_custom_field_map] = {}

      allowed_field_ids =
        if guardian.is_staff?
          UserField.pluck(:id)
        else
          UserField.public_fields.pluck(:id)
        end

      user_field_ids = params[:user_field_ids].split("|").map(&:to_i) & allowed_field_ids
      user_field_ids.each do |user_field_id|
        serializer_opts[:user_custom_field_map][
          "#{User::USER_FIELD_PREFIX}#{user_field_id}"
        ] = user_field_id
      end
    end

    if params[:plugin_column_ids]
      serializer_opts[:plugin_column_ids] = params[:plugin_column_ids]&.split("|")&.map(&:to_i)
    end

    serializer_opts[:attributes] = query_result.active_column_names
    serializer_opts[:searchable_fields] = UserField.where(searchable: true) if serializer_opts[
      :user_custom_field_map
    ].present?

    serialized = serialize_data(query_result.items, DirectoryItemSerializer, serializer_opts)
    render_json_dump(
      directory_items: serialized,
      meta: {
        last_updated_at: query_result.last_updated_at,
        total_rows_directory_items: query_result.total,
        load_more_directory_items: load_more_directory_items_json,
      },
    )
  end
end
