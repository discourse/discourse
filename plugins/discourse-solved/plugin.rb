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
end

require_relative "lib/discourse_solved/engine"

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-solved", "db", "fixtures").to_s

  module ::DiscourseSolved
    def self.accept_answer!(post, acting_user, topic: nil)
      topic ||= post.topic

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        solved = topic.solved

        ActiveRecord::Base.transaction do
          if previous_accepted_post_id = solved&.answer_post_id
            UserAction.where(
              action_type: UserAction::SOLVED,
              target_post_id: previous_accepted_post_id,
            ).destroy_all
            solved.destroy!
          else
            UserAction.log_action!(
              action_type: UserAction::SOLVED,
              user_id: post.user_id,
              acting_user_id: acting_user.id,
              target_post_id: post.id,
              target_topic_id: post.topic_id,
            )
          end

          solved =
            DiscourseSolved::SolvedTopic.new(topic:, answer_post: post, accepter: acting_user)

          unless acting_user.id == post.user_id
            Notification.create!(
              notification_type: Notification.types[:custom],
              user_id: post.user_id,
              topic_id: post.topic_id,
              post_number: post.post_number,
              data: {
                message: "solved.accepted_notification",
                display_username: acting_user.username,
                topic_title: topic.title,
                title: "solved.notification.title",
              }.to_json,
            )
          end

          if SiteSetting.notify_on_staff_accept_solved && acting_user.id != topic.user_id
            Notification.create!(
              notification_type: Notification.types[:custom],
              user_id: topic.user_id,
              topic_id: post.topic_id,
              post_number: post.post_number,
              data: {
                message: "solved.accepted_notification",
                display_username: acting_user.username,
                topic_title: topic.title,
                title: "solved.notification.title",
              }.to_json,
            )
          end

          auto_close_hours = 0
          if topic&.category.present?
            auto_close_hours = topic.category.custom_fields["solved_topics_auto_close_hours"].to_i
            auto_close_hours = 175_200 if auto_close_hours > 175_200 # 20 years
          end

          auto_close_hours = SiteSetting.solved_topics_auto_close_hours if auto_close_hours == 0

          if (auto_close_hours > 0) && !topic.closed
            topic_timer =
              topic.set_or_create_timer(
                TopicTimer.types[:silent_close],
                nil,
                based_on_last_post: true,
                duration_minutes: auto_close_hours * 60,
              )
            solved.topic_timer = topic_timer

            MessageBus.publish("/topic/#{topic.id}", reload_topic: true)
          end

          solved.save!
        end

        if WebHook.active_web_hooks(:accepted_solution).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:accepted_solution, post, payload)
        end

        accepted_answer = topic.reload.accepted_answer_post_info

        message = { type: :accepted_solution, accepted_answer: }

        DiscourseEvent.trigger(:accepted_solution, post)

        secure_audience = topic.secure_audience_publish_messages
        # MessageBus.publish will raise an error if user_ids or group_ids are an empty array.
        if secure_audience[:user_ids] != [] && secure_audience[:group_ids] != []
          MessageBus.publish("/topic/#{topic.id}", message, secure_audience)
        end

        accepted_answer
      end
    end

    def self.unaccept_answer!(post, topic: nil)
      topic ||= post.topic
      topic ||= Topic.unscoped.find_by(id: post.topic_id)
      return if topic.nil?
      return if topic.solved.nil?

      DistributedMutex.synchronize("discourse_solved_toggle_answer_#{topic.id}") do
        solved = topic.solved

        ActiveRecord::Base.transaction do
          UserAction.where(action_type: UserAction::SOLVED, target_post_id: post.id).destroy_all
          Notification.find_by(
            notification_type: Notification.types[:custom],
            user_id: post.user_id,
            topic_id: post.topic_id,
            post_number: post.post_number,
          )&.destroy!
          solved.destroy!
        end

        if WebHook.active_web_hooks(:unaccepted_solution).exists?
          payload = WebHook.generate_payload(:post, post)
          WebHook.enqueue_solved_hooks(:unaccepted_solution, post, payload)
        end

        DiscourseEvent.trigger(:unaccepted_solution, post)
        MessageBus.publish("/topic/#{topic.id}", type: :unaccepted_solution)
      end
    end

    def self.skip_db?
      defined?(GlobalSetting.skip_db?) && GlobalSetting.skip_db?
    end
  end

  reloadable_patch do
    ::Guardian.prepend(DiscourseSolved::GuardianExtensions)
    ::WebHook.prepend(DiscourseSolved::WebHookExtension)
    ::TopicViewSerializer.prepend(DiscourseSolved::TopicViewSerializerExtension)
    ::Topic.prepend(DiscourseSolved::TopicExtension)
    ::Category.prepend(DiscourseSolved::CategoryExtension)
    ::PostSerializer.prepend(DiscourseSolved::PostSerializerExtension)
    ::UserSummary.prepend(DiscourseSolved::UserSummaryExtension)
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
      DiscourseSolved::SolvedTopic.joins(:topic).where(
        "topics.archetype <> ?",
        Archetype.private_message,
      )

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
    DiscourseSolved::SolvedTopic
      .joins(answer_post: :user, topic: {})
      .where(posts: { user_id: object.id, deleted_at: nil })
      .where(topics: { archetype: Archetype.default, deleted_at: nil })
      .count
  end
  add_to_serializer(:user_summary, :solved_count) { object.solved_count }
  add_to_serializer(:post, :can_accept_answer) { scope.can_accept_answer?(topic, object) }
  add_to_serializer(:post, :can_unaccept_answer) do
    scope.can_accept_answer?(topic, object) && accepted_answer
  end
  add_to_serializer(:post, :accepted_answer) { topic&.solved&.answer_post_id == object.id }
  add_to_serializer(:post, :topic_accepted_answer) { topic&.solved&.present? }

  on(:post_destroyed) { |post| DiscourseSolved.unaccept_answer!(post) }

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
    category_id_changes = topic_changes.diff["category_id"].to_a
    tag_changes = topic_changes.diff["tags"].to_a

    old_allowed = Guardian.new.allow_accepted_answers?(category_id_changes[0], tag_changes[0])
    new_allowed = Guardian.new.allow_accepted_answers?(category_id_changes[1], tag_changes[1])

    options[:refresh_stream] = true if old_allowed != new_allowed
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
