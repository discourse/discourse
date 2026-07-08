# frozen_string_literal: true

# name: discourse-solved
# about: Allows users to accept solutions on topics in designated categories.
# meta_topic_id: 30155
# version: 0.1
# authors: Sam Saffron
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-solved

enabled_site_setting :solved_enabled

register_svg_icon "far-square-check"
register_svg_icon "square-check"
register_svg_icon "far-square"

register_asset "stylesheets/solutions.scss"
register_asset "stylesheets/admin/dashboard-support.scss", :admin

module ::DiscourseSolved
  PLUGIN_NAME = "discourse-solved"
  ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD = "enable_accepted_answers"
  NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD = "notify_on_staff_accept_solved"
  EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD = "empty_box_on_unsolved"
  SHARED_ISSUES_ENABLED_CUSTOM_FIELD = "enable_shared_issues"
  MAX_AUTO_CLOSE_HOURS = 20.years.to_i / 1.hour.to_i

  def self.accept_answer!(post, acting_user, topic: nil)
    DiscourseSolved::AcceptAnswer.call(params: { post_id: post.id }, guardian: acting_user.guardian)
  end

  def self.unaccept_answer!(post, topic: nil)
    DiscourseSolved::UnacceptAnswer.call(
      params: {
        post_id: post.id,
      },
      guardian: Discourse.system_user.guardian,
    )
  end
end

require_relative "lib/discourse_solved/engine"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins/discourse-solved/db/fixtures").to_s

  UserUpdater::OPTION_ATTR.push(:notify_on_solved)
  add_to_serializer(:user_option, :notify_on_solved) { object.notify_on_solved }

  reloadable_patch do
    register_category_type(DiscourseSolved::Categories::Types::Support)
    ::Guardian.prepend(DiscourseSolved::GuardianExtensions)
    ::WebHook.prepend(DiscourseSolved::WebHookExtension)
    ::TopicViewSerializer.prepend(DiscourseSolved::TopicViewSerializerExtension)
    ::Topic.prepend(DiscourseSolved::TopicExtension)
    ::User.prepend(DiscourseSolved::UserExtension)
    ::Category.prepend(DiscourseSolved::CategoryExtension)
    ::PostSerializer.prepend(DiscourseSolved::PostSerializerExtension)
    ::PostMover.prepend(DiscourseSolved::PostMoverExtension)
    ::UserSummary.prepend(DiscourseSolved::UserSummaryExtension)
    ::UpcomingChanges::ConditionalDisplay.extend(
      DiscourseSolved::UpcomingChangesConditionalDisplayExtension,
    )

    ::Topic.attr_accessor(:accepted_answer_user_ids)
    ::TopicPostersSummary.alias_method(:old_user_ids, :user_ids)
    ::TopicPostersSummary.prepend(DiscourseSolved::TopicPostersSummaryExtension)
    [
      ::TopicListItemSerializer,
      ::SearchTopicListItemSerializer,
      ::SuggestedTopicSerializer,
      ::UserSummarySerializer::TopicSerializer,
      ::ListableTopicSerializer,
    ].each { |klass| klass.include(DiscourseSolved::TopicAnswerMixin) }
  end

  solved_topic_answer_preload = { solved: :topic_answers }

  if SiteSetting.solved_enabled
    register_category_list_topics_preloader_associations(solved_topic_answer_preload)
    register_topic_preloader_associations(solved_topic_answer_preload)
    Search.custom_topic_eager_load { [solved_topic_answer_preload] }
  end

  TopicView.on_preload do |topic_view|
    next unless SiteSetting.solved_enabled

    solved = topic_view.topic.solved
    next unless solved

    ActiveRecord::Associations::Preloader.new(
      records: [solved],
      associations: {
        topic_answers: [{ post: :user }, :accepter],
      },
    ).call
  end

  register_preloaded_category_custom_fields(DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD)
  register_preloaded_category_custom_fields(
    DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD,
  )
  register_preloaded_category_custom_fields(DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD)
  register_preloaded_category_custom_fields(DiscourseSolved::SHARED_ISSUES_ENABLED_CUSTOM_FIELD)

  add_api_key_scope(
    :solved,
    { answer: { actions: %w[discourse_solved/answer#accept discourse_solved/answer#unaccept] } },
  )

  register_modifier(:topic_crawler_container_schema) do |schema, topic|
    DiscourseSolved::SchemaUtils.container_schema(topic) || schema
  end

  register_modifier(:topic_crawler_main_entity_schema) do |schema, topic|
    DiscourseSolved::SchemaUtils.main_entity_schema(topic) || schema
  end

  register_modifier(:topic_crawler_post_schema) do |schema, post, topic|
    DiscourseSolved::SchemaUtils.post_schema(post, topic) || schema
  end

  register_modifier(:topic_crawler_skip_post) do |default, post, topic|
    DiscourseSolved::SchemaUtils.qa_page_schema?(topic) &&
      post.post_type == Post.types[:small_action]
  end

  register_html_builder("server:topic-main-entity-meta-crawler") do |controller|
    topic_view = controller.instance_variable_get(:@topic_view)
    DiscourseSolved::SchemaUtils.main_entity_meta(topic_view&.topic, topic_view&.crawler_posts)
  end

  register_html_builder("server:topic-show-crawler-post-end") do |controller, post:|
    topic = controller.instance_variable_get(:@topic_view)&.topic
    DiscourseSolved::SchemaUtils.post_answer_meta(post, topic) if topic
  end

  register_html_builder("server:before-head-close-crawler") do |controller|
    topic_view = controller.instance_variable_get(:@topic_view)
    result =
      DiscourseSolved::BuildSchemaMarkup.call(
        params: {
          topic_id: topic_view&.topic&.id,
          post_ids: topic_view&.posts&.ids,
        },
        guardian: controller.guardian,
      )
    result[:html] if result.success?
  end

  register_html_builder("server:before-head-close") do |controller|
    topic_view = controller.instance_variable_get(:@topic_view)
    result =
      DiscourseSolved::BuildSchemaMarkup.call(
        params: {
          topic_id: topic_view&.topic&.id,
          post_ids: topic_view&.posts&.ids,
        },
        guardian: controller.guardian,
      )
    result[:html] if result.success?
  end

  Report.add_report("accepted_solutions") do |report|
    report.data = []

    accepted_solutions =
      DiscourseSolved::SolvedTopic
        .joins(:topic)
        .where.not(topics: { archetype: Archetype.private_message })

    category_id, include_subcategories = report.add_category_filter
    if category_id
      if include_subcategories
        accepted_solutions =
          accepted_solutions.where(
            "topics.category_id IN (?)",
            Category.subcategory_ids(category_id),
          )
      else
        accepted_solutions = accepted_solutions.where("topics.category_id = ?", category_id)
      end
    end

    accepted_solutions
      .where("discourse_solved_solved_topics.created_at >= ?", report.start_date)
      .where("discourse_solved_solved_topics.created_at <= ?", report.end_date)
      .group("DATE(discourse_solved_solved_topics.created_at)")
      .order("DATE(discourse_solved_solved_topics.created_at)")
      .count
      .each { |date, count| report.data << { x: date, y: count } }
    report.total = accepted_solutions.count
    report.prev30Days =
      accepted_solutions
        .where("discourse_solved_solved_topics.created_at >= ?", report.start_date - 30.days)
        .where("discourse_solved_solved_topics.created_at <= ?", report.start_date)
        .count

    if report.facets.include?(:prev_period)
      report.prev_period =
        accepted_solutions
          .where("discourse_solved_solved_topics.created_at >= ?", report.prev_start_date)
          .where("discourse_solved_solved_topics.created_at < ?", report.prev_end_date)
          .count
    end
  end

  register_admin_dashboard_highlight_kpi(
    type: :accepted_solutions,
    report: "accepted_solutions",
    enabled: -> do
      next true if SiteSetting.allow_solved_on_all_topics

      Discourse
        .cache
        .fetch("solved_admin_dashboard_kpi_enabled", expires_in: 5.minutes) do
          Category
            .joins(
              "INNER JOIN category_custom_fields ON category_custom_fields.category_id = categories.id",
            )
            .where(
              category_custom_fields: {
                name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
                value: "true",
              },
            )
            .exists?
        end
    end,
  )

  register_admin_dashboard_section(
    id: "support",
    enabled: -> { DiscourseSolved::AdminDashboardSupport.available? },
  ) do |start_date:, end_date:, current_user:|
    DiscourseSolved::AdminDashboardSupport.build(
      start_date: start_date,
      end_date: end_date,
      current_user: current_user,
    )
  end

  register_modifier(:search_rank_sort_priorities) do |priorities, _search|
    if SiteSetting.prioritize_solved_topics_in_search
      condition = <<~SQL
        EXISTS (
          SELECT 1
            FROM discourse_solved_solved_topics
           WHERE discourse_solved_solved_topics.topic_id = topics.id
        )
      SQL

      priorities.push([condition, 1.1])
    else
      priorities
    end
  end

  register_modifier(:user_action_stream_builder) do |builder|
    builder.where("t.deleted_at IS NULL").where("t.archetype <> ?", Archetype.private_message)
  end

  add_to_serializer(:user_card, :accepted_answers) do
    DiscourseSolved::Queries.solved_count(object.id)
  end
  add_to_serializer(:user_summary, :solved_count) { object.solved_count }
  add_to_serializer(:post, :can_accept_answer) { scope.can_accept_answer?(topic, object) }
  add_to_serializer(:post, :can_unaccept_answer) do
    scope.can_unaccept_answer?(topic, object) && accepted_answer
  end
  add_to_serializer(:post, :accepted_answer) do
    topic&.topic_answers&.any? { |topic_answer| topic_answer.answer_post_id == object.id }
  end
  add_to_serializer(:post, :topic_accepted_answer) { topic&.solved&.present? }

  add_to_serializer(
    :topic_view,
    :shared_issue_count,
    include_condition: -> { scope.shared_issue_visible?(object.topic) },
  ) { DiscourseSolved::SharedIssue.count_for(object.topic) }
  add_to_serializer(
    :topic_view,
    :user_created_shared_issue,
    include_condition: -> { scope.shared_issue_visible?(object.topic) && scope.user.present? },
  ) { DiscourseSolved::SharedIssue.exists?(topic_id: object.topic.id, user_id: scope.user.id) }
  add_to_serializer(:topic_view, :can_create_shared_issue) do
    scope.can_create_shared_issue?(object.topic)
  end
  add_to_serializer(:topic_view, :shared_issue_visible) do
    scope.shared_issue_visible?(object.topic)
  end

  on(:upcoming_change_enabled) do |setting_name|
    if setting_name == :enable_solved_badges
      DiscourseSolved::EnableSolvedBadgesToggled.call(enabled: true)
    end
  end

  on(:upcoming_change_disabled) do |setting_name|
    if setting_name == :enable_solved_badges
      DiscourseSolved::EnableSolvedBadgesToggled.call(enabled: false)
    end
  end

  on(:post_destroyed) do |post|
    DiscourseSolved::UnacceptAnswer.call(
      params: {
        post_id: post.id,
      },
      guardian: Discourse.system_user.guardian,
    )
  end

  on(:filter_auto_bump_topics) do |_category, filters|
    filters.push(
      ->(r) do
        sql = <<~SQL
          NOT EXISTS (
            SELECT 1
              FROM discourse_solved_solved_topics
             WHERE discourse_solved_solved_topics.topic_id = topics.id
          )
        SQL

        r.where(sql)
      end,
    )
  end

  on(:before_post_publish_changes) do |post_changes, topic_changes, options|
    topic = topic_changes.topic
    current_tag_names = topic.tags.map(&:name)

    category_id_diff = topic_changes.diff["category_id"]
    tag_diff = topic_changes.diff["tags"]

    old_category_id = category_id_diff ? category_id_diff[0] : topic.category_id
    old_tags = tag_diff ? tag_diff[0] : current_tag_names

    old_allowed = Guardian.new.solved_enabled_for_category?(old_category_id, old_tags)
    new_allowed = Guardian.new.solved_enabled_for_category?(topic.category_id, current_tag_names)

    if old_allowed != new_allowed
      options[:refresh_stream] = true

      if !new_allowed
        topic.topic_answers.each do |ta|
          DiscourseSolved::UnacceptAnswer.call(
            params: {
              post_id: ta.answer_post_id,
            },
            guardian: Discourse.system_user.guardian,
          )
        end
      end
    end
  end

  query = <<~SQL
    UPDATE directory_items di
       SET solutions = 0
     WHERE di.period_type = :period_type AND di.solutions IS NOT NULL;

    WITH x AS (
    SELECT p.user_id, COUNT(DISTINCT sta.id) AS solutions
      FROM discourse_solved_solved_topics AS st
      JOIN discourse_solved_topic_answers AS sta
        ON sta.solved_topic_id = st.id
       AND COALESCE(sta.created_at, :since) > :since
      JOIN posts AS p
        ON p.id = sta.answer_post_id
       AND p.deleted_at IS NULL
      JOIN topics AS t
        ON t.id = st.topic_id
       AND t.archetype <> 'private_message'
       AND t.deleted_at IS NULL
      JOIN users AS u
        ON u.id = p.user_id
     WHERE u.id > 0
       AND u.active
       AND u.silenced_till IS NULL
       AND u.suspended_till IS NULL
     GROUP BY p.user_id
    )
    UPDATE directory_items di
       SET solutions = x.solutions
      FROM x
     WHERE x.user_id = di.user_id
       AND di.period_type = :period_type;
  SQL

  add_directory_column("solutions", query:)

  add_to_class(:composer_messages_finder, :check_topic_is_solved) do
    return if !SiteSetting.solved_enabled || SiteSetting.disable_solved_education_message
    return if !replying? || @topic.blank? || @topic.private_message?
    return if @topic.solved.nil?

    {
      id: "solved_topic",
      templateName: "education",
      wait_for_typing: true,
      extraClass: "education-message",
      hide_if_whisper: true,
      body: PrettyText.cook(I18n.t("education.topic_is_solved", base_url: Discourse.base_url)),
    }
  end

  register_topic_list_preload_user_ids do |topics, user_ids|
    # [{ topic_id => answer_user_id }, ... ]
    topics_with_answer_users =
      DiscourseSolved::SolvedTopic
        .joins(topic_answers: :post)
        .where(topic_id: topics.map(&:id))
        .distinct
        .pluck("discourse_solved_solved_topics.topic_id", "posts.user_id")
        .each_with_object({}) { |(topic_id, user_id), h| (h[topic_id] ||= []) << user_id }

    topics.each do |topic|
      topic.accepted_answer_user_ids = topics_with_answer_users[topic.id] || []
    end

    user_ids.concat(topics_with_answer_users.values.flatten.uniq)
  end

  DiscourseSolved::RegisterFilters.register(self)

  DiscourseDev::DiscourseSolved.populate(self)
  DiscourseAutomation::EntryPoint.inject(self) if defined?(DiscourseAutomation)
end
