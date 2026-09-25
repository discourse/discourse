# frozen_string_literal: true

class GroupDirectoryQuery
  TYPE_FILTERS = {
    my:
      Proc.new do |groups, user|
        raise Discourse::NotFound unless user
        Group.member_of(groups, user)
      end,
    owner:
      Proc.new do |groups, user|
        raise Discourse::NotFound unless user
        Group.owner_of(groups, user)
      end,
    public: Proc.new { |groups| groups.where(public_admission: true, automatic: false) },
    close: Proc.new { |groups| groups.where(public_admission: false, automatic: false) },
    automatic: Proc.new { |groups| groups.where(automatic: true) },
    non_automatic: Proc.new { |groups| groups.where(automatic: false) },
  }.freeze

  Result = Data.define(:groups, :total, :type_filters, :order, :memberships)

  def initialize(user:, guardian:, modifier_context:)
    @user = user
    @guardian = guardian
    @modifier_context = modifier_context
  end

  def call(username: nil, filter: nil, type: nil, order: nil, ascending: false, page: 0, limit: 36)
    unless SiteSetting.enable_group_directory? || user&.staff?
      raise Discourse::InvalidAccess.new(:enable_group_directory)
    end

    groups = Group.visible_groups(user)
    type_filters = TYPE_FILTERS.keys

    if username.present?
      target_user = User.find_by_username(username)
      raise Discourse::NotFound if target_user.blank?

      groups = TYPE_FILTERS[:my].call(groups.members_visible_groups(user), target_user)
      type_filters -= %i[my owner]
    end

    groups = Group.search_groups(filter, groups:) if filter.present?

    if !guardian.is_staff?
      groups =
        groups.where("groups.automatic IS FALSE OR groups.id = ?", Group::AUTO_GROUPS[:moderators])
      type_filters.delete(:automatic)
    end

    if type.present?
      type = type.to_sym
      callback = TYPE_FILTERS[type]
      raise Discourse::InvalidParameters.new(:type) if callback.blank?

      groups = callback.call(groups, user)
    end

    groups = DiscoursePluginRegistry.apply_modifier(:groups_index_query, groups, modifier_context)
    type_filters.delete(:non_automatic)
    type_filters -= %i[my owner] if user.blank?

    order = allowed_order(groups, order)
    groups = apply_order(groups, order, ascending)
    total = groups.count
    groups = groups.offset(page * limit).limit(limit).to_a
    if Group.preloaded_custom_field_names.present?
      Group.preload_custom_fields(groups, Group.preloaded_custom_field_names)
    end
    memberships = user ? GroupUser.where(group: groups, user:).index_by(&:group_id) : {}

    Result.new(groups:, total:, type_filters:, order:, memberships:)
  end

  private

  attr_reader :guardian, :modifier_context, :user

  def allowed_order(groups, requested_order)
    requested_order = %w[name user_count].delete(requested_order)
    return requested_order if requested_order != "user_count"

    member_visible_group_ids = Group.members_visible_groups(user).unscope(:order).select(:id)
    requested_order if !groups.unscope(:order).where.not(id: member_visible_group_ids).exists?
  end

  def apply_order(groups, order, ascending)
    return groups if order.blank?

    direction = ascending ? "ASC" : "DESC"
    sort =
      if order == "user_count"
        "groups.user_count #{direction}, groups.name ASC"
      else
        "groups.name #{direction}"
      end
    groups.reorder(sort)
  end
end
