# frozen_string_literal: true

class DirectoryItemsQuery
  PAGE_SIZE = 50
  PAGE_LIMIT = 10

  GroupNotFound = Class.new(StandardError)
  Result = Data.define(:items, :total, :last_updated_at, :period_type, :active_column_names)

  def initialize(user:, guardian:)
    @user = user
    @guardian = guardian
  end

  def call(
    period_type:,
    group_name: nil,
    exclude_group_names: nil,
    exclude_usernames: nil,
    order: nil,
    ascending: false,
    name: nil,
    username: nil,
    page: 0,
    limit: PAGE_SIZE,
    prioritize_user: false
  )
    items = DirectoryItem.where(period_type:).includes(user: %i[user_custom_fields primary_group])
    items = filter_group(items, group_name) if group_name.present?
    items, excluded_user_ids = exclude_groups(items, exclude_group_names)
    items = exclude_usernames(items, exclude_usernames)
    items = filter_name(items, name, prioritize_user:)
    items = filter_username(items, username)
    items = order_items(items, order, ascending)
    items = items.includes(:user_stat) if period_type == DirectoryItem.period_types[:all]

    total = items.count
    page_items = items.limit(limit).offset(limit * page).to_a
    if prioritize_user
      prioritize_user!(page_items, period_type:, page:, group_name:, excluded_user_ids:)
    end

    Result.new(
      items: page_items,
      total:,
      last_updated_at: DirectoryItem.last_updated_at(period_type),
      period_type:,
      active_column_names: DirectoryColumn.active_column_names,
    )
  end

  private

  attr_reader :guardian, :user

  def filter_group(items, group_name)
    group = Group.find_by(name: group_name)
    raise GroupNotFound if group.blank?

    guardian.ensure_can_see_group_and_members!(group)
    items.joins(user: :groups).where(groups: { id: group.id })
  end

  def exclude_groups(items, group_names)
    return items, [] if group_names.blank?

    group_ids =
      Group
        .where(name: group_names)
        .select { |group| guardian.can_see_group_and_members?(group) }
        .map(&:id)
    excluded_user_ids = GroupUser.where(group_id: group_ids).pluck(:user_id)
    [items.where.not(user_id: excluded_user_ids), excluded_user_ids]
  end

  def exclude_usernames(items, usernames)
    return items if usernames.blank?

    user_ids = User.where(username_lower: usernames.map(&:downcase)).select(:id)
    items.where.not(user_id: user_ids)
  end

  def filter_name(items, name, prioritize_user:)
    return items if name.blank?

    user_ids =
      UserSearch
        .new(
          name,
          include_staged_users: true,
          user_directory_search: true,
          limit: 200,
          search_custom_fields: true,
          searching_user: user,
        )
        .search
        .pluck(:id)
    return items.where("false") if user_ids.empty?

    user_ids << user.id if prioritize_user && user && items.where(user_id: user_ids).exists?
    items.where(user_id: user_ids)
  end

  def filter_username(items, username)
    return items if username.blank?

    user_id = User.where(username_lower: username.downcase).pick(:id)
    user_id ? items.where(user_id:) : items.where("false")
  end

  def order_items(items, requested_order, ascending)
    default_order = DirectoryColumn.automatic_column_names.first
    order = requested_order.presence || default_order.to_s
    direction = ascending ? :asc : :desc

    if DirectoryColumn.active_column_names.include?(order.to_sym)
      items.order(order => direction, :id => :asc)
    elsif order == "username"
      items.joins(:user).order(users: { username: direction }, id: :asc)
    else
      order_by_user_field(items, order, direction, default_order)
    end
  end

  def order_by_user_field(items, order, direction, default_order)
    user_field_scope = guardian.is_staff? ? UserField.all : UserField.public_fields
    user_field = user_field_scope.find_by(name: order)
    return items.order(default_order => direction, :id => :asc) if user_field.blank?

    field_name = "#{User::USER_FIELD_PREFIX}#{user_field.id}"
    items
      .joins(
        ActiveRecord::Base.sanitize_sql_array(
          [
            "LEFT OUTER JOIN user_custom_fields ON " \
              "user_custom_fields.user_id = directory_items.user_id AND " \
              "user_custom_fields.name = ?",
            field_name,
          ],
        ),
      )
      .order(
        Arel.sql(
          "user_custom_fields.name = #{ActiveRecord::Base.connection.quote(field_name)} ASC",
        ),
      )
      .order(user_custom_fields: { value: direction })
  end

  def prioritize_user!(items, period_type:, page:, group_name:, excluded_user_ids:)
    return if items.empty? || user.blank? || page != 0 || group_name.present?

    position = items.index { |item| item.user_id == user.id }
    return if (position || 10) < 10 || excluded_user_ids.include?(user.id)

    user_item =
      DirectoryItem
        .where(period_type:, user_id: user.id)
        .includes(:user_stat, user: %i[user_custom_fields primary_group])
        .first
    items.insert(0, user_item) if user_item
  end
end
