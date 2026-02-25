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
register_asset "stylesheets/mobile/solutions.scss", :mobile

module ::DiscourseSolved
  PLUGIN_NAME = "discourse-solved"
  ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD = "enable_accepted_answers"
  MAX_AUTO_CLOSE_HOURS = 20.years.to_i / 1.hour.to_i
end

require_relative "lib/discourse_solved/engine"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-solved", "db", "fixtures").to_s

  reloadable_patch do
    ::Guardian.prepend(DiscourseSolved::GuardianExtensions)
    ::WebHook.prepend(DiscourseSolved::WebHookExtension)
    ::TopicViewSerializer.prepend(DiscourseSolved::TopicViewSerializerExtension)
    ::Topic.prepend(DiscourseSolved::TopicExtension)
    ::Category.prepend(DiscourseSolved::CategoryExtension)
    ::PostSerializer.prepend(DiscourseSolved::PostSerializerExtension)
    ::UserSummary.prepend(DiscourseSolved::UserSummaryExtension)
    ::TopicsController.prepend(DiscourseSolved::TopicsControllerExtension)
    ::Topic.attr_accessor(:accepted_answer_user_id)
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

  register_category_list_topics_preloader_associations(:solved) if SiteSetting.solved_enabled
  register_topic_preloader_associations(:solved) if SiteSetting.solved_enabled
  Search.custom_topic_eager_load { [:solved] } if SiteSetting.solved_enabled
  Site.preloaded_category_custom_fields << DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD

  add_api_key_scope(
    :solved,
    { answer: { actions: %w[discourse_solved/answer#accept discourse_solved/answer#unaccept] } },
  )

  register_html_builder("server:before-head-close-crawler") do |controller|
    DiscourseSolved::BeforeHeadClose.new(controller).html
  end

  register_html_builder("server:before-head-close") do |controller|
    DiscourseSolved::BeforeHeadClose.new(controller).html
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
  add_to_serializer(:post, :accepted_answer) { topic&.solved&.answer_post_id == object.id }
  add_to_serializer(:post, :topic_accepted_answer) { topic&.solved&.present? }

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
        if topic.solved.present?
          post = topic.solved.answer_post
          if post
            DiscourseSolved::UnacceptAnswer.call(
              params: {
                post_id: post.id,
              },
              guardian: Discourse.system_user.guardian,
            )
          end
        end
      end
    end
  end

  query = <<~SQL
    UPDATE directory_items di
       SET solutions = 0
     WHERE di.period_type = :period_type AND di.solutions IS NOT NULL;

    WITH x AS (
      SELECT p.user_id, COUNT(DISTINCT st.id) AS solutions
      FROM discourse_solved_solved_topics AS st
      JOIN posts AS p
         ON p.id = st.answer_post_id
        AND COALESCE(st.created_at, :since) > :since
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
    topics_with_answer_poster =
      DiscourseSolved::SolvedTopic
        .joins(:answer_post)
        .where(topic_id: topics.map(&:id))
        .pluck(:topic_id, "posts.user_id")
        .to_h

    topics.each { |topic| topic.accepted_answer_user_id = topics_with_answer_poster[topic.id] }
    user_ids.concat(topics_with_answer_poster.values)
  end

  DiscourseSolved::RegisterFilters.register(self)

  DiscourseDev::DiscourseSolved.populate(self)
  DiscourseAutomation::EntryPoint.inject(self) if defined?(DiscourseAutomation)
  DiscourseAssign::EntryPoint.inject(self) if defined?(DiscourseAssign)
end
