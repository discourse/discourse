# frozen_string_literal: true

# name: discourse-assign
# about: Provides the ability to assign topics and individual posts to a user or group.
# meta_topic_id: 58044
# version: 1.0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-assign

enabled_site_setting :assign_enabled

register_asset "stylesheets/assigns.scss"
register_asset "stylesheets/mobile/assigns.scss", :mobile

%w[user-plus user-xmark group-plus group-times].each { |i| register_svg_icon(i) }

module ::DiscourseAssign
  PLUGIN_NAME = "discourse-assign"
end

require_relative "lib/discourse_assign/engine"
require_relative "lib/validators/assign_statuses_validator"

after_initialize do
  UserUpdater::OPTION_ATTR.push(:notification_level_when_assigned)

  reloadable_patch do |plugin|
    Group.prepend(DiscourseAssign::GroupExtension)
    ListController.prepend(DiscourseAssign::ListControllerExtension)
    Post.prepend(DiscourseAssign::PostExtension)
    Topic.prepend(DiscourseAssign::TopicExtension)
    WebHook.prepend(DiscourseAssign::WebHookExtension)
    Notification.prepend(DiscourseAssign::NotificationExtension)
    UserOption.prepend(DiscourseAssign::UserOptionExtension)
  end

  add_to_serializer(:user_option, :notification_level_when_assigned) do
    object.notification_level_when_assigned
  end

  add_to_serializer(:current_user_option, :notification_level_when_assigned) do
    object.notification_level_when_assigned
  end

  register_group_param(:assignable_level)
  register_groups_callback_for_users_search_controller_action(:assignable_groups) do |groups, user|
    groups.assignable(user)
  end

  frequency_field = PendingAssignsReminder::REMINDERS_FREQUENCY
  register_editable_user_custom_field frequency_field
  register_user_custom_field_type(frequency_field, :integer, max_length: 10)
  DiscoursePluginRegistry.serialized_current_user_fields << frequency_field
  add_to_serializer(:user, :reminders_frequency) { RemindAssignsFrequencySiteSettings.values }

  add_to_serializer(:group_show, :assignment_count, include_condition: -> { scope.can_assign? }) do
    Topic.joins(<<~SQL).where(<<~SQL, group_id: object.id).where("topics.deleted_at IS NULL").count
        JOIN assignments a
        ON topics.id = a.topic_id AND a.assigned_to_id IS NOT NULL
      SQL
        a.active AND
        ((
          a.assigned_to_type = 'User' AND a.assigned_to_id IN (
            SELECT group_users.user_id
            FROM group_users
            WHERE group_id = :group_id
          )
        ) OR (
          a.assigned_to_type = 'Group' AND a.assigned_to_id = :group_id
        ))
      SQL
  end

  add_to_serializer(:group_show, :assignable_level) { object.assignable_level }

  add_to_serializer(:group_show, :can_show_assigned_tab?) { object.can_show_assigned_tab? }

  add_model_callback(UserCustomField, :before_save) do
    self.value = self.value.to_i if self.name == frequency_field
  end

  add_class_method(:group, :assign_allowed_groups) do
    allowed_groups = SiteSetting.assign_allowed_on_groups.split("|")
    where(id: allowed_groups)
  end

  add_to_class(:user, :can_assign?) do
    return @can_assign if defined?(@can_assign)

    allowed_groups = SiteSetting.assign_allowed_on_groups.split("|").compact
    @can_assign = admin? || (allowed_groups.present? && groups.where(id: allowed_groups).exists?)
  end

  add_to_serializer(:current_user, :never_auto_track_topics) do
    (
      user.user_option.auto_track_topics_after_msecs ||
        SiteSetting.default_other_auto_track_topics_after_msecs
    ) < 0
  end

  add_to_class(:group, :can_show_assigned_tab?) do
    allowed_group_ids = SiteSetting.assign_allowed_on_groups.split("|")

    group_has_disallowed_users =
      DB.query_single(<<~SQL, allowed_group_ids: allowed_group_ids, current_group_id: self.id)[0]
      SELECT EXISTS(
        SELECT 1 FROM users
        JOIN group_users current_group_users
          ON current_group_users.user_id=users.id
          AND current_group_users.group_id = :current_group_id
        LEFT JOIN group_users allowed_group_users
          ON allowed_group_users.user_id=users.id
          AND allowed_group_users.group_id IN (:allowed_group_ids)
        WHERE allowed_group_users.user_id IS NULL
      )
    SQL

    !group_has_disallowed_users
  end

  add_to_class(:guardian, :can_assign?) { user && user.can_assign? }

  add_class_method(:user, :assign_allowed) do
    allowed_groups = SiteSetting.assign_allowed_on_groups.split("|")

    # The UNION against admin users is necessary because bot users like the system user are given the admin status but
    # are not added into the admin group.
    where(
      "users.id IN (
      SELECT
        user_id
      FROM group_users
      WHERE group_users.group_id IN (?)

      UNION

      SELECT id
      FROM users
      WHERE users.admin
    )",
      allowed_groups,
    )
  end

  add_model_callback(Group, :before_update) do
    if name_changed?
      SiteSetting.assign_allowed_on_groups =
        SiteSetting.assign_allowed_on_groups.gsub(name_was, name)
    end
  end

  add_model_callback(Group, :before_destroy) do
    new_setting = SiteSetting.assign_allowed_on_groups.gsub(/#{id}[|]?/, "")
    new_setting = new_setting.chomp("|") if new_setting.ends_with?("|")
    SiteSetting.assign_allowed_on_groups = new_setting
  end

  on(:assign_topic) do |topic, user, assigning_user, force|
    Assigner.new(topic, assigning_user).assign(user) if force || !Assignment.exists?(target: topic)
  end

  on(:unassign_topic) { |topic, unassigning_user| Assigner.new(topic, unassigning_user).unassign }

  if respond_to?(:register_preloaded_category_custom_fields)
    register_preloaded_category_custom_fields("enable_unassigned_filter")
  else
    # TODO: Drop the if-statement and this if-branch in Discourse v3.2
    Site.preloaded_category_custom_fields << "enable_unassigned_filter"
  end

  BookmarkQuery.on_preload do |bookmarks, _bookmark_query|
    if SiteSetting.assign_enabled?
      topics =
        Bookmark
          .select_type(bookmarks, "Topic")
          .map(&:bookmarkable)
          .concat(Bookmark.select_type(bookmarks, "Post").map { |bm| bm.bookmarkable.topic })
          .uniq
      assignments =
        Assignment
          .strict_loading
          .where(topic_id: topics)
          .includes(:assigned_to)
          .index_by(&:topic_id)

      topics.each do |topic|
        assignment = assignments[topic.id]
        # NOTE: preloading to `nil` is necessary to avoid N+1 queries
        topic.preload_assigned_to(assignment&.assigned_to)
        topic.preload_assignment_status(assignment&.status)
      end
    end
  end

  TopicView.on_preload do |topic_view|
    topic_view.instance_variable_set(:@posts, topic_view.posts.includes(:assignment))
  end

  TopicList.on_preload do |topics, topic_list|
    next unless SiteSetting.assign_enabled?

    can_assign = topic_list.current_user&.can_assign?
    allowed_access = SiteSetting.assigns_public || can_assign

    next if !allowed_access || topics.empty?

    assignments =
      Assignment.strict_loading.active.where(topic: topics).includes(:target, :assigned_to)
    assignments_map = assignments.group_by(&:topic_id)

    user_ids = assignments.filter(&:assigned_to_user?).map(&:assigned_to_id)
    users_map = User.where(id: user_ids).select(UserLookup.lookup_columns).index_by(&:id)

    group_ids = assignments.filter(&:assigned_to_group?).map(&:assigned_to_id)
    groups_map = Group.where(id: group_ids).index_by(&:id)

    topics.each do |topic|
      if assignments = assignments_map[topic.id]
        topic_assignments, post_assignments = assignments.partition { _1.target_type == "Topic" }

        direct_assignment = topic_assignments.find { _1.target_id == topic.id }

        indirectly_assigned_to = {}

        post_assignments.each do |assignment|
          next unless assignment.target

          if assignment.assigned_to_user?
            indirectly_assigned_to[assignment.target_id] = {
              assigned_to: users_map[assignment.assigned_to_id],
              post_number: assignment.target.post_number,
            }
          elsif assignment.assigned_to_group?
            indirectly_assigned_to[assignment.target_id] = {
              assigned_to: groups_map[assignment.assigned_to_id],
              post_number: assignment.target.post_number,
            }
          end
        end

        assigned_to =
          if direct_assignment&.assigned_to_user?
            users_map[direct_assignment.assigned_to_id]
          elsif direct_assignment&.assigned_to_group?
            groups_map[direct_assignment.assigned_to_id]
          end
      end

      # NOTE: preloading to `nil` is necessary to avoid N+1 queries
      topic.preload_assigned_to(assigned_to)
      topic.preload_assignment_status(direct_assignment&.status)
      topic.preload_indirectly_assigned_to(indirectly_assigned_to)
    end
  end

  Search.on_preload do |results, search|
    next unless SiteSetting.assign_enabled?

    can_assign = search.guardian&.can_assign?
    allowed_access = SiteSetting.assigns_public || can_assign

    next if !allowed_access || results.posts.empty?

    topics = results.posts.map(&:topic)

    assignments =
      Assignment
        .strict_loading
        .active
        .where(topic: topics)
        .includes(:assigned_to, :target)
        .group_by(&:topic_id)

    results.posts.each do |post|
      if topic_assignments = assignments[post.topic_id]
        direct_assignment = topic_assignments.find { _1.target_type == "Topic" }
        indirect_assignments = topic_assignments.select { _1.target_type == "Post" }
      end

      if indirect_assignments.present?
        indirect_assignment_map = {}

        indirect_assignments.each do |assignment|
          next unless assignment.target
          indirect_assignment_map[assignment.target_id] = {
            assigned_to: assignment.assigned_to,
            post_number: assignment.target.post_number,
          }
        end
      end

      # NOTE: preloading to `nil` is necessary to avoid N+1 queries
      post.topic.preload_assigned_to(direct_assignment&.assigned_to)
      post.topic.preload_assignment_status(direct_assignment&.status)
      post.topic.preload_indirectly_assigned_to(indirect_assignment_map)
    end
  end

  # TopicQuery
  TopicQuery.add_custom_filter(:assigned) do |results, topic_query|
    name = topic_query.options[:assigned]
    next results if name.blank?

    next results if !topic_query.guardian.can_assign? && !SiteSetting.assigns_public

    if name == "nobody"
      next(
        results.joins("LEFT JOIN assignments a ON a.topic_id = topics.id AND active").where(
          "a.assigned_to_id IS NULL",
        )
      )
    end

    if name == "*"
      next(
        results.joins("JOIN assignments a ON a.topic_id = topics.id AND active").where(
          "a.assigned_to_id IS NOT NULL",
        )
      )
    end

    user_id = topic_query.guardian.user.id if name == "me"
    user_id ||= User.where(username_lower: name.downcase).pick(:id)

    if user_id
      next(
        results.joins("JOIN assignments a ON a.topic_id = topics.id AND active").where(
          "a.assigned_to_id = ? AND a.assigned_to_type = 'User'",
          user_id,
        )
      )
    end

    group_id = Group.where(name: name.downcase).pick(:id)

    if group_id
      next(
        results.joins("JOIN assignments a ON a.topic_id = topics.id AND active").where(
          "a.assigned_to_id = ? AND a.assigned_to_type = 'Group'",
          group_id,
        )
      )
    end

    next results
  end

  add_to_class(:topic_query, :list_messages_assigned) do |user, ignored_assignment_ids = nil|
    list = default_results(include_pms: true)

    where_clause = +"("
    where_clause << "(assigned_to_id = :user_id AND assigned_to_type = 'User' AND active)"
    if @options[:filter] != :direct
      where_clause << "OR (assigned_to_id IN (group_users.group_id) AND assigned_to_type = 'Group' AND active)"
    end
    where_clause << ")"

    if ignored_assignment_ids.present?
      where_clause << "AND assignments.id NOT IN (:ignored_assignment_ids)"
    end
    topic_ids_sql = +<<~SQL
      SELECT topic_id FROM assignments
      LEFT JOIN group_users ON group_users.user_id = :user_id
      WHERE #{where_clause}
    SQL

    where_args = { user_id: user.id }
    where_args[:ignored_assignment_ids] = ignored_assignment_ids if ignored_assignment_ids.present?
    list = list.where("topics.id IN (#{topic_ids_sql})", **where_args).includes(:allowed_users)

    create_list(:assigned, { unordered: true }, list)
  end

  add_to_class(:topic_query, :group_topics_assigned_results) do |group|
    list = default_results(include_all_pms: true)

    topic_ids_sql = +<<~SQL
      SELECT topic_id FROM assignments
      WHERE (
        assigned_to_id = :group_id AND assigned_to_type = 'Group' AND active
      )
    SQL

    topic_ids_sql << <<~SQL if @options[:filter] != :direct
        OR (
          assigned_to_id IN (SELECT user_id from group_users where group_id = :group_id) AND assigned_to_type = 'User' AND active
        )
      SQL

    sql = "topics.id IN (#{topic_ids_sql})"

    list = list.where(sql, group_id: group.id).includes(:allowed_users)
  end

  add_to_class(:topic_query, :list_group_topics_assigned) do |group|
    create_list(:assigned, { unordered: true }, group_topics_assigned_results(group))
  end

  add_to_class(:topic_query, :list_private_messages_assigned) do |user|
    list = private_messages_assigned_query(user)
    create_list(:private_messages, {}, list)
  end

  add_to_class(:topic_query, :private_messages_assigned_query) do |user|
    list = private_messages_for(user, :all)

    group_ids = user.groups.map(&:id)

    list = list.where(<<~SQL, user_id: user.id, group_ids: group_ids)
      topics.id IN (
        SELECT topic_id FROM assignments WHERE
        active AND
        ((assigned_to_id = :user_id AND assigned_to_type = 'User') OR
        (assigned_to_id IN (:group_ids) AND assigned_to_type = 'Group'))
      )
    SQL
  end

  # ListController
  add_to_class(:list_controller, :messages_assigned) do
    user = User.find_by_username(params[:username])
    raise Discourse::NotFound unless user
    raise Discourse::InvalidAccess unless current_user.can_assign?

    list_opts = build_topic_list_options
    list_opts.merge!({ filter: :direct }) if params[:direct] == "true"
    list = generate_list_for("messages_assigned", user, list_opts)

    list.more_topics_url = construct_url_with(:next, list_opts)
    list.prev_topics_url = construct_url_with(:prev, list_opts)

    respond_with_list(list)
  end

  add_to_class(:list_controller, :group_topics_assigned) do
    group = Group.find_by("name = ?", params[:groupname])
    guardian.ensure_can_see_group_members!(group)

    raise Discourse::NotFound unless group
    raise Discourse::InvalidAccess unless current_user.can_assign?
    raise Discourse::InvalidAccess unless group.can_show_assigned_tab?

    list_opts = build_topic_list_options
    list_opts.merge!({ filter: :direct }) if params[:direct] == "true"
    list = generate_list_for("group_topics_assigned", group, list_opts)

    list.more_topics_url = construct_url_with(:next, list_opts)
    list.prev_topics_url = construct_url_with(:prev, list_opts)

    respond_with_list(list)
  end

  # Topic
  add_to_class(:topic, :assigned_to) do
    return @assigned_to if defined?(@assigned_to)
    @assigned_to = assignment.assigned_to if assignment&.active
  end

  add_to_class(:topic, :assignment_status) do
    return @assignment_status if defined?(@assignment_status)
    @assignment_status = assignment.status if SiteSetting.enable_assign_status && assignment&.active
  end

  add_to_class(:topic, :indirectly_assigned_to) do
    return @indirectly_assigned_to if defined?(@indirectly_assigned_to)
    @indirectly_assigned_to =
      Assignment
        .where(topic_id: id, target_type: "Post", active: true)
        .includes(:target)
        .inject({}) do |acc, assignment|
          if assignment.target
            acc[assignment.target_id] = {
              assigned_to: assignment.assigned_to,
              post_number: assignment.target.post_number,
              assignment_note: assignment.note,
            }
            acc[assignment.target_id][
              :assignment_status
            ] = assignment.status if SiteSetting.enable_assign_status
          end
          acc
        end
  end

  add_to_class(:topic, :preload_assigned_to) { |assigned_to| @assigned_to = assigned_to }

  add_to_class(:topic, :preload_assignment_status) do |assignment_status|
    @assignment_status = assignment_status
  end

  add_to_class(:topic, :preload_indirectly_assigned_to) do |indirectly_assigned_to|
    @indirectly_assigned_to = indirectly_assigned_to
  end

  # TopicList serializer
  add_to_serializer(
    :topic_list,
    :assigned_messages_count,
    include_condition: -> do
      options = object.instance_variable_get(:@opts)

      if assigned_user = options.dig(:assigned)
        scope.can_assign? || assigned_user.downcase == scope.current_user&.username_lower
      end
    end,
  ) do
    TopicQuery
      .new(object.current_user, guardian: scope, limit: false)
      .private_messages_assigned_query(object.current_user)
      .count
  end

  # TopicView serializer
  add_to_serializer(
    :topic_view,
    :assigned_to_user,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.topic.assigned_to.is_a?(User)
    end,
  ) { DiscourseAssign::Helpers.build_assigned_to_user(object.topic.assigned_to, object.topic) }

  add_to_serializer(
    :topic_view,
    :assigned_to_group,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.topic.assigned_to.is_a?(Group)
    end,
  ) { DiscourseAssign::Helpers.build_assigned_to_group(object.topic.assigned_to, object.topic) }

  add_to_serializer(
    :topic_view,
    :indirectly_assigned_to,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) &&
        object.topic.indirectly_assigned_to.present?
    end,
  ) do
    DiscourseAssign::Helpers.build_indirectly_assigned_to(
      object.topic.indirectly_assigned_to,
      object.topic,
    )
  end

  add_to_serializer(
    :topic_view,
    :assignment_note,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.topic.assignment.present?
    end,
  ) { object.topic.assignment.note }

  add_to_serializer(
    :topic_view,
    :assignment_status,
    include_condition: -> do
      SiteSetting.enable_assign_status && (SiteSetting.assigns_public || scope.can_assign?) &&
        object.topic.assignment_status.present?
    end,
  ) { object.topic.assignment_status }

  # SuggestedTopic serializer
  add_to_serializer(
    :suggested_topic,
    :assigned_to_user,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(User)
    end,
  ) { DiscourseAssign::Helpers.build_assigned_to_user(object.assigned_to, object) }

  add_to_serializer(
    :suggested_topic,
    :assigned_to_group,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(Group)
    end,
  ) { DiscourseAssign::Helpers.build_assigned_to_group(object.assigned_to, object) }

  add_to_serializer(
    :suggested_topic,
    :indirectly_assigned_to,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.indirectly_assigned_to.present?
    end,
  ) { DiscourseAssign::Helpers.build_indirectly_assigned_to(object.indirectly_assigned_to, object) }

  # TopicListItem serializer
  add_to_serializer(
    :topic_list_item,
    :indirectly_assigned_to,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.indirectly_assigned_to.present?
    end,
  ) { DiscourseAssign::Helpers.build_indirectly_assigned_to(object.indirectly_assigned_to, object) }

  add_to_serializer(
    :topic_list_item,
    :assigned_to_user,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(User)
    end,
  ) { BasicUserSerializer.new(object.assigned_to, scope: scope, root: false).as_json }

  add_to_serializer(
    :topic_list_item,
    :assigned_to_group,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(Group)
    end,
  ) { AssignedGroupSerializer.new(object.assigned_to, scope: scope, root: false).as_json }

  add_to_serializer(
    :topic_list_item,
    :assignment_status,
    include_condition: -> do
      SiteSetting.enable_assign_status && (SiteSetting.assigns_public || scope.can_assign?) &&
        object.assignment_status.present?
    end,
  ) { object.assignment_status }

  # SearchTopicListItem serializer
  add_to_serializer(
    :search_topic_list_item,
    :assigned_to_user,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(User)
    end,
  ) { DiscourseAssign::Helpers.build_assigned_to_user(object.assigned_to, object) }

  add_to_serializer(
    :search_topic_list_item,
    :assigned_to_group,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assigned_to.is_a?(Group)
    end,
  ) { AssignedGroupSerializer.new(object.assigned_to, scope: scope, root: false).as_json }

  add_to_serializer(
    :search_topic_list_item,
    :indirectly_assigned_to,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.indirectly_assigned_to.present?
    end,
  ) { DiscourseAssign::Helpers.build_indirectly_assigned_to(object.indirectly_assigned_to, object) }

  # TopicsBulkAction
  TopicsBulkAction.register_operation("assign") do
    if @user.can_assign?
      assign_user = User.find_by_username(@operation[:username])
      topics.each do |topic|
        Assigner.new(topic, @user).assign(
          assign_user,
          status: @operation[:status],
          note: @operation[:note],
        )
      end
    end
  end

  TopicsBulkAction.register_operation("unassign") do
    if @user.can_assign?
      topics.each { |topic| Assigner.new(topic, @user).unassign if guardian.can_assign? }
    end
  end

  register_permitted_bulk_action_parameter :username
  register_permitted_bulk_action_parameter :status
  register_permitted_bulk_action_parameter :note

  add_to_class(:user_bookmark_base_serializer, :assigned_to) do
    @assigned_to ||=
      bookmarkable_type == "Topic" ? bookmarkable.assigned_to : bookmarkable.topic.assigned_to
  end

  add_to_class(:user_bookmark_base_serializer, :can_have_assignment?) do
    %w[Post Topic].include?(bookmarkable_type)
  end

  add_to_serializer(
    :user_bookmark_base,
    :assigned_to_user,
    include_condition: -> do
      return false if !can_have_assignment?
      (SiteSetting.assigns_public || scope.can_assign?) && assigned_to.is_a?(User)
    end,
  ) do
    return if !can_have_assignment?
    BasicUserSerializer.new(assigned_to, scope: scope, root: false).as_json
  end

  add_to_serializer(
    :user_bookmark_base,
    :assigned_to_group,
    include_condition: -> do
      return false if !can_have_assignment?
      (SiteSetting.assigns_public || scope.can_assign?) && assigned_to.is_a?(Group)
    end,
  ) do
    return if !can_have_assignment?
    AssignedGroupSerializer.new(assigned_to, scope: scope, root: false).as_json
  end

  # PostSerializer
  add_to_serializer(
    :post,
    :assigned_to_user,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) &&
        object.assignment&.assigned_to.is_a?(User) && object.assignment.active
    end,
  ) { BasicUserSerializer.new(object.assignment.assigned_to, scope: scope, root: false).as_json }

  add_to_serializer(
    :post,
    :assigned_to_group,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) &&
        object.assignment&.assigned_to.is_a?(Group) && object.assignment.active
    end,
  ) do
    AssignedGroupSerializer.new(object.assignment.assigned_to, scope: scope, root: false).as_json
  end

  add_to_serializer(
    :post,
    :assignment_note,
    include_condition: -> do
      (SiteSetting.assigns_public || scope.can_assign?) && object.assignment.present?
    end,
  ) { object.assignment.note }

  add_to_serializer(
    :post,
    :assignment_status,
    include_condition: -> do
      SiteSetting.enable_assign_status && (SiteSetting.assigns_public || scope.can_assign?) &&
        object.assignment.present?
    end,
  ) { object.assignment.status }

  # CurrentUser serializer
  add_to_serializer(:current_user, :can_assign) { object.can_assign? }

  # FlaggedTopic serializer
  add_to_serializer(
    :flagged_topic,
    :assigned_to_user,
    include_condition: -> { object.assigned_to && object.assigned_to.is_a?(User) },
  ) { DiscourseAssign::Helpers.build_assigned_to_user(object.assigned_to, object) }

  add_to_serializer(
    :flagged_topic,
    :assigned_to_group,
    include_condition: -> { object.assigned_to && object.assigned_to.is_a?(Group) },
  ) { DiscourseAssign::Helpers.build_assigned_to_group(object.assigned_to, object) }

  # Reviewable
  add_custom_reviewable_filter(
    [
      :assigned_to,
      Proc.new do |results, value|
        results.joins(<<~SQL).where(target_type: Post.name).where("u.username = ?", value)
          INNER JOIN posts p ON p.id = target_id
          INNER JOIN topics t ON t.id = p.topic_id
          INNER JOIN assignments a ON a.topic_id = t.id AND a.assigned_to_type = 'User'
          INNER JOIN users u ON u.id = a.assigned_to_id
        SQL
      end,
    ],
  )

  # TopicTrackingState
  add_class_method(:topic_tracking_state, :publish_assigned_private_message) do |topic, assignee|
    return unless topic.private_message?
    opts = (assignee.is_a?(User) ? { user_ids: [assignee.id] } : { group_ids: [assignee.id] })

    MessageBus.publish("/private-messages/assigned", { topic_id: topic.id }, opts)
  end

  # Event listeners
  on(:post_created) { |post| ::Assigner.auto_assign(post, force: true) }

  on(:post_edited) { |post, topic_changed| ::Assigner.auto_assign(post, force: true) }

  on(:topic_status_updated) do |topic, status, enabled|
    if SiteSetting.unassign_on_close && (status == "closed" || status == "autoclosed") && enabled &&
         Assignment.active.exists?(topic: topic)
      assigner = ::Assigner.new(topic, Discourse.system_user)
      assigner.unassign(silent: true, deactivate: true)

      topic
        .posts
        .joins(:assignment)
        .find_each do |post|
          assigner = ::Assigner.new(post, Discourse.system_user)
          assigner.unassign(silent: true, deactivate: true)
        end
      MessageBus.publish("/topic/#{topic.id}", reload_topic: true, refresh_stream: true)
    end

    if SiteSetting.reassign_on_open && (status == "closed" || status == "autoclosed") && !enabled &&
         Assignment.inactive.exists?(topic: topic)
      Assignment.reactivate!(topic: topic)
      MessageBus.publish("/topic/#{topic.id}", reload_topic: true, refresh_stream: true)
    end
  end

  on(:post_destroyed) do |post|
    if Assignment.active.exists?(target: post)
      post.assignment.deactivate!
      MessageBus.publish("/topic/#{post.topic_id}", reload_topic: true, refresh_stream: true)
    end

    # small actions have to be destroyed as link is incorrect
    PostCustomField
      .where(name: "action_code_post_id", value: post.id)
      .find_each do |post_custom_field|
        next if post_custom_field.post == nil
        if ![Post.types[:small_action], Post.types[:whisper]].include?(
             post_custom_field.post.post_type,
           )
          next
        end
        post_custom_field.post.destroy
      end
  end

  on(:post_recovered) do |post|
    if SiteSetting.reassign_on_open && Assignment.inactive.exists?(target: post)
      post.assignment.reactivate!
      MessageBus.publish("/topic/#{post.topic_id}", reload_topic: true, refresh_stream: true)
    end
  end

  on(:move_to_inbox) do |info|
    topic = info[:topic]

    if topic.assignment
      TopicTrackingState.publish_assigned_private_message(topic, topic.assignment.assigned_to)
    end

    next if !SiteSetting.unassign_on_group_archive
    next if !info[:group]

    Assignment.reactivate!(topic: topic)
  end

  on(:archive_message) do |info|
    topic = info[:topic]
    next if !topic.assignment

    TopicTrackingState.publish_assigned_private_message(topic, topic.assignment.assigned_to)

    next if !SiteSetting.unassign_on_group_archive
    next if !info[:group]

    Assignment.deactivate!(topic: topic)
  end

  on(:user_added_to_group) do |user, group, automatic:|
    group.assignments.active.find_each do |assignment|
      Jobs.enqueue(:assign_notification, assignment_id: assignment.id)
    end
  end

  on(:user_removed_from_group) do |user, group|
    user.notifications.for_assignment(group.assignments.select(:id)).destroy_all
  end

  on(:post_moved) do |post, original_topic_id|
    assignment =
      Assignment.where(topic_id: original_topic_id, target_type: "Post", target_id: post.id).first
    next if !assignment
    if post.is_first_post?
      assignment.update!(topic_id: post.topic_id, target_type: "Topic", target_id: post.topic_id)
    else
      assignment.update!(topic_id: post.topic_id)
    end
  end

  on(:group_destroyed) do |group, user_ids|
    User
      .where(id: user_ids)
      .find_each do |user|
        user.notifications.for_assignment(group.assignments.select(:id)).destroy_all
      end

    Assignment.active_for_group(group).destroy_all
  end

  add_filter_custom_filter("assigned") do |scope, filter_values, guardian|
    next if !guardian.can_assign? || filter_values.blank?

    user_or_group_name = filter_values.compact.first

    next if user_or_group_name.blank?

    if user_id = User.find_by_username(user_or_group_name)&.id
      scope.where(<<~SQL, user_id)
        topics.id IN (SELECT a.topic_id FROM assignments a WHERE a.assigned_to_id = ? AND a.assigned_to_type = 'User' AND a.active)
      SQL
    elsif group_id = Group.find_by(name: user_or_group_name)&.id
      scope.where(<<~SQL, group_id)
        topics.id IN (SELECT a.topic_id FROM assignments a WHERE a.assigned_to_id = ? AND a.assigned_to_type = 'Group' AND a.active)
      SQL
    end
  end

  register_search_advanced_filter(/in:assigned/) do |posts|
    next if !@guardian.can_assign?

    posts.where("topics.id IN (SELECT a.topic_id FROM assignments a WHERE a.active)")
  end

  register_search_advanced_filter(/in:unassigned/) do |posts|
    next if !@guardian.can_assign?

    posts.where("topics.id NOT IN (SELECT a.topic_id FROM assignments a WHERE a.active)")
  end

  register_search_advanced_filter(/assigned:(.+)$/) do |posts, match|
    next if !@guardian.can_assign? || match.blank?

    if user_id = User.find_by_username(match)&.id
      posts.where(<<~SQL, user_id)
        topics.id IN (SELECT a.topic_id FROM assignments a WHERE a.assigned_to_id = ? AND a.assigned_to_type = 'User' AND a.active)
      SQL
    elsif group_id = Group.find_by(name: match)&.id
      posts.where(<<~SQL, group_id)
        topics.id IN (SELECT a.topic_id FROM assignments a WHERE a.assigned_to_id = ? AND a.assigned_to_type = 'Group' AND a.active)
      SQL
    end
  end

  if defined?(DiscourseAutomation)
    add_automation_scriptable("random_assign") do
      field :assignees_group, component: :group, required: true
      field :assigned_topic, component: :text, required: true
      field :minimum_time_between_assignments, component: :text
      field :max_recently_assigned_days, component: :text
      field :min_recently_assigned_days, component: :text
      field :skip_new_users_for_days, component: :text
      field :in_working_hours, component: :boolean
      field :post_template, component: :post

      version 1

      triggerables %i[point_in_time recurring]

      script do |context, fields, automation|
        RandomAssignUtils.automation_script!(context, fields, automation)
      end
    end
  end
end
