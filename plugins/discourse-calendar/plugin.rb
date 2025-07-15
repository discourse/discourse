# frozen_string_literal: true

# name: discourse-calendar
# about: Adds the ability to create a dynamic calendar with events in a topic.
# meta_topic_id: 97376
# version: 0.5
# author: Daniel Waterworth, Joffrey Jaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-calendar

libdir = File.join(File.dirname(__FILE__), "vendor/holidays/lib")
$LOAD_PATH.unshift(libdir) if $LOAD_PATH.exclude?(libdir)

require_relative "lib/calendar_settings_validator.rb"

enabled_site_setting :calendar_enabled

register_asset "stylesheets/vendor/fullcalendar.min.css"
register_asset "stylesheets/common/discourse-calendar.scss"
register_asset "stylesheets/common/discourse-calendar-holidays.scss"
register_asset "stylesheets/common/upcoming-events-calendar.scss"
register_asset "stylesheets/common/discourse-post-event.scss"
register_asset "stylesheets/common/discourse-post-event-preview.scss"
register_asset "stylesheets/common/post-event-builder.scss"
register_asset "stylesheets/common/discourse-post-event-invitees.scss"
register_asset "stylesheets/common/discourse-post-event-upcoming-events.scss"
register_asset "stylesheets/common/discourse-post-event-core-ext.scss"
register_asset "stylesheets/mobile/discourse-post-event-core-ext.scss", :mobile
register_asset "stylesheets/common/discourse-post-event-bulk-invite-modal.scss"
register_asset "stylesheets/mobile/discourse-calendar.scss", :mobile
register_asset "stylesheets/mobile/discourse-post-event.scss", :mobile
register_asset "stylesheets/desktop/discourse-calendar.scss", :desktop
register_asset "stylesheets/colors.scss", :color_definitions
register_asset "stylesheets/common/user-preferences.scss"
register_asset "stylesheets/common/upcoming-events-list.scss"
register_svg_icon "calendar-day"
register_svg_icon "clock"
register_svg_icon "file-csv"
register_svg_icon "star"
register_svg_icon "file-arrow-up"
register_svg_icon "location-pin"

module ::DiscourseCalendar
  PLUGIN_NAME = "discourse-calendar"

  # Type of calendar ('static' or 'dynamic')
  CALENDAR_CUSTOM_FIELD = "calendar"

  # User custom field set when user is on holiday
  HOLIDAY_CUSTOM_FIELD = "on_holiday"

  # List of all users on holiday
  USERS_ON_HOLIDAY_KEY = "users_on_holiday"

  # User region used in finding holidays
  REGION_CUSTOM_FIELD = "holidays-region"

  # List of groups
  GROUP_TIMEZONES_CUSTOM_FIELD = "group-timezones"

  def self.users_on_holiday
    PluginStore.get(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY) || []
  end

  def self.users_on_holiday=(usernames)
    PluginStore.set(PLUGIN_NAME, USERS_ON_HOLIDAY_KEY, usernames)
  end
end

module ::DiscoursePostEvent
  PLUGIN_NAME = "discourse-post-event"

  # Topic where op has a post event custom field
  TOPIC_POST_EVENT_STARTS_AT = "TopicEventStartsAt"
  TOPIC_POST_EVENT_ENDS_AT = "TopicEventEndsAt"
end

require_relative "lib/discourse_calendar/engine"

Dir
  .glob(File.expand_path("../lib/discourse_calendar/site_settings/*.rb", __FILE__))
  .each { |f| require(f) }

after_initialize do
  reloadable_patch do
    Category.register_custom_field_type("sort_topics_by_event_start_date", :boolean)
    Category.register_custom_field_type("disable_topic_resorting", :boolean)
    if respond_to?(:register_preloaded_category_custom_fields)
      register_preloaded_category_custom_fields("sort_topics_by_event_start_date")
      register_preloaded_category_custom_fields("disable_topic_resorting")
    else
      # TODO: Drop the if-statement and this if-branch in Discourse v3.2
      Site.preloaded_category_custom_fields << "sort_topics_by_event_start_date"
      Site.preloaded_category_custom_fields << "disable_topic_resorting"
    end
  end

  add_to_serializer :basic_category, :sort_topics_by_event_start_date do
    object.custom_fields["sort_topics_by_event_start_date"]
  end

  add_to_serializer :basic_category, :disable_topic_resorting do
    object.custom_fields["disable_topic_resorting"]
  end

  reloadable_patch do
    TopicQuery.add_custom_filter(:order_by_event_date) do |results, topic_query|
      if SiteSetting.sort_categories_by_event_start_date_enabled &&
           topic_query.options[:category_id]
        category = Category.find_by(id: topic_query.options[:category_id])
        if category && category.custom_fields &&
             category.custom_fields["sort_topics_by_event_start_date"]
          reorder_sql = <<~SQL
           CASE WHEN COALESCE(custom_fields.value::timestamptz, topics.bumped_at) > NOW() THEN 0 ELSE 1 END,
           CASE WHEN COALESCE(custom_fields.value::timestamptz, topics.bumped_at) > NOW() THEN COALESCE(custom_fields.value::timestamptz, topics.bumped_at) ELSE NULL END,
           CASE WHEN COALESCE(custom_fields.value::timestamptz, topics.bumped_at) < NOW() THEN COALESCE(custom_fields.value::timestamptz, topics.bumped_at) ELSE NULL END DESC
          SQL
          results =
            results.joins(
              "LEFT JOIN topic_custom_fields AS custom_fields on custom_fields.topic_id = topics.id
         AND custom_fields.name = '#{DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT}'
         ",
            ).reorder(reorder_sql)
        end
      end
      results
    end
  end

  # DISCOURSE CALENDAR HOLIDAYS

  add_admin_route "admin.calendar", "calendar"

  # DISCOURSE POST EVENT

  require_relative "jobs/regular/discourse_post_event/bulk_invite"
  require_relative "jobs/regular/discourse_post_event/bump_topic"
  require_relative "jobs/regular/discourse_post_event/send_reminder"
  require_relative "lib/discourse_post_event/engine"
  require_relative "lib/discourse_post_event/event_finder"
  require_relative "lib/discourse_post_event/event_parser"
  require_relative "lib/discourse_post_event/event_validator"
  require_relative "lib/discourse_post_event/export_csv_controller_extension"
  require_relative "lib/discourse_post_event/export_csv_file_extension"
  require_relative "lib/discourse_post_event/post_extension"
  require_relative "lib/discourse_post_event/rrule_generator"
  require_relative "lib/discourse_post_event/rrule_configurator"

  ::ActionController::Base.prepend_view_path File.expand_path("../app/views", __FILE__)

  reloadable_patch do
    ExportCsvController.prepend(DiscoursePostEvent::ExportCsvControllerExtension)
    Jobs::ExportCsvFile.prepend(DiscoursePostEvent::ExportPostEventCsvReportExtension)
    Post.prepend(DiscoursePostEvent::PostExtension)
  end

  add_to_class(:user, :can_create_discourse_post_event?) do
    return @can_create_discourse_post_event if defined?(@can_create_discourse_post_event)
    @can_create_discourse_post_event =
      begin
        return true if staff?
        allowed_groups = SiteSetting.discourse_post_event_allowed_on_groups.to_s.split("|").compact
        allowed_groups.present? &&
          (
            allowed_groups.include?(Group::AUTO_GROUPS[:everyone].to_s) ||
              groups.where(id: allowed_groups).exists?
          )
      rescue StandardError
        false
      end
  end

  add_to_class(:guardian, :can_act_on_invitee?) do |invitee|
    user && (user.staff? || user.id == invitee.user_id)
  end

  add_to_class(:guardian, :can_create_discourse_post_event?) do
    user && user.can_create_discourse_post_event?
  end

  add_to_serializer(:current_user, :can_create_discourse_post_event) do
    object.can_create_discourse_post_event?
  end

  add_to_class(:user, :can_act_on_discourse_post_event?) do |event|
    return @can_act_on_discourse_post_event if defined?(@can_act_on_discourse_post_event)
    @can_act_on_discourse_post_event =
      begin
        return true if staff?
        can_create_discourse_post_event? && Guardian.new(self).can_edit_post?(event.post)
      rescue StandardError
        false
      end
  end

  add_to_class(:guardian, :can_act_on_discourse_post_event?) do |event|
    user && user.can_act_on_discourse_post_event?(event)
  end

  add_class_method(:group, :discourse_post_event_allowed_groups) do
    where(id: SiteSetting.discourse_post_event_allowed_on_groups.split("|").compact)
  end

  TopicView.on_preload do |topic_view|
    if SiteSetting.discourse_post_event_enabled
      topic_view.instance_variable_set(:@posts, topic_view.posts.includes(:event))
    end
  end

  add_to_serializer(
    :post,
    :event,
    include_condition: -> do
      SiteSetting.discourse_post_event_enabled && !object.nil? && !object.deleted_at.present?
    end,
  ) { DiscoursePostEvent::EventSerializer.new(object.event, scope: scope, root: false) }

  on(:post_created) { |post| DiscoursePostEvent::Event.update_from_raw(post) }

  on(:post_edited) { |post| DiscoursePostEvent::Event.update_from_raw(post) }

  on(:post_destroyed) do |post|
    if SiteSetting.discourse_post_event_enabled && post.event
      post.event.update!(deleted_at: Time.now)
    end
  end

  on(:post_recovered) do |post|
    post.event.update!(deleted_at: nil) if SiteSetting.discourse_post_event_enabled && post.event
  end

  add_preloaded_topic_list_custom_field DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT

  add_to_serializer(
    :topic_view,
    :event_starts_at,
    include_condition: -> do
      SiteSetting.discourse_post_event_enabled &&
        SiteSetting.display_post_event_date_on_topic_title &&
        object.topic.custom_fields.keys.include?(DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT)
    end,
  ) { object.topic.custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT] }

  add_to_class(:topic, :event_starts_at) do
    @event_starts_at ||= custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_STARTS_AT]
  end

  add_to_serializer(
    :topic_list_item,
    :event_starts_at,
    include_condition: -> do
      SiteSetting.discourse_post_event_enabled &&
        SiteSetting.display_post_event_date_on_topic_title && object.event_starts_at
    end,
  ) { object.event_starts_at }

  add_preloaded_topic_list_custom_field DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT

  add_to_serializer(
    :topic_view,
    :event_ends_at,
    include_condition: -> do
      SiteSetting.discourse_post_event_enabled &&
        SiteSetting.display_post_event_date_on_topic_title &&
        object.topic.custom_fields.keys.include?(DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT)
    end,
  ) { object.topic.custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT] }

  add_to_class(:topic, :event_ends_at) do
    @event_ends_at ||= custom_fields[DiscoursePostEvent::TOPIC_POST_EVENT_ENDS_AT]
  end

  add_to_serializer(
    :topic_list_item,
    :event_ends_at,
    include_condition: -> do
      SiteSetting.discourse_post_event_enabled &&
        SiteSetting.display_post_event_date_on_topic_title && object.event_ends_at
    end,
  ) { object.event_ends_at }

  # DISCOURSE CALENDAR

  require_relative "jobs/scheduled/create_holiday_events"
  require_relative "jobs/scheduled/delete_expired_event_posts"
  require_relative "jobs/scheduled/monitor_event_dates"
  require_relative "jobs/scheduled/update_holiday_usernames"
  require_relative "lib/calendar_validator"
  require_relative "lib/calendar"
  require_relative "lib/event_validator"
  require_relative "lib/group_timezones"
  require_relative "lib/holiday_status"
  require_relative "lib/time_sniffer"
  require_relative "lib/users_on_holiday"

  register_post_custom_field_type(DiscourseCalendar::CALENDAR_CUSTOM_FIELD, :string)
  register_post_custom_field_type(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD, :json)
  TopicView.default_post_custom_fields << DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD

  register_user_custom_field_type(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD, :boolean)

  allow_staff_user_custom_field(DiscourseCalendar::HOLIDAY_CUSTOM_FIELD)
  DiscoursePluginRegistry.serialized_current_user_fields << DiscourseCalendar::REGION_CUSTOM_FIELD
  register_editable_user_custom_field(DiscourseCalendar::REGION_CUSTOM_FIELD)
  register_user_custom_field_type(DiscourseCalendar::REGION_CUSTOM_FIELD, :string, max_length: 40)

  on(:site_setting_changed) do |name, old_value, new_value|
    next if %i[all_day_event_start_time all_day_event_end_time].exclude? name

    Post
      .where(id: CalendarEvent.select(:post_id).distinct)
      .each { |post| CalendarEvent.update(post) }
  end

  on(:post_process_cooked) do |doc, post|
    DiscourseCalendar::Calendar.update(post)
    DiscourseCalendar::GroupTimezones.update(post)
    CalendarEvent.update(post)
  end

  on(:post_recovered) do |post, _, _|
    DiscourseCalendar::Calendar.update(post)
    DiscourseCalendar::GroupTimezones.update(post)
    CalendarEvent.update(post)
  end

  on(:post_destroyed) do |post, _, _|
    DiscourseCalendar::Calendar.destroy(post)
    CalendarEvent.where(post_id: post.id).destroy_all
  end

  validate(:post, :validate_calendar) do |force = nil|
    return unless self.raw_changed? || force

    validator = DiscourseCalendar::CalendarValidator.new(self)
    validator.validate_calendar
  end

  validate(:post, :validate_event) do |force = nil|
    return unless self.raw_changed? || force
    return if self.is_first_post?

    # Skip if not a calendar topic
    return if !self.topic&.first_post&.custom_fields&.[](DiscourseCalendar::CALENDAR_CUSTOM_FIELD)

    validator = DiscourseCalendar::EventValidator.new(self)
    validator.validate_event
  end

  add_to_class(:post, :has_group_timezones?) do
    custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD].present?
  end

  add_to_class(:post, :group_timezones) do
    custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
  end

  add_to_class(:post, :group_timezones=) do |val|
    if val.present?
      custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] = val
    else
      custom_fields.delete(DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD)
    end
  end

  add_to_serializer(:post, :calendar_details, include_condition: -> { object.is_first_post? }) do
    start_date = 6.months.ago

    standalone_sql = <<~SQL
      SELECT post_number, description, start_date, end_date, username, recurrence, timezone
        FROM calendar_events
       WHERE topic_id = :topic_id
         AND post_id IS NOT NULL
       ORDER BY start_date, end_date
    SQL

    standalones =
      DB
        .query(standalone_sql, topic_id: object.topic_id)
        .map do |row|
          {
            type: :standalone,
            post_number: row.post_number,
            message: row.description,
            from: row.start_date,
            to: row.end_date,
            username: row.username,
            recurring: row.recurrence,
            post_url: Post.url("-", object.topic_id, row.post_number),
            timezone: row.timezone,
          }
        end

    timezones =
      UserOption
        .where(
          user_id:
            CalendarEvent.where(
              topic_id: object.topic_id,
              post_id: nil,
              start_date: start_date..,
            ).select(:user_id),
        )
        .where("LENGTH(COALESCE(timezone, '')) > 0")
        .pluck(:user_id, :timezone)
        .to_h

    grouped = {}

    grouped_sql = <<~SQL
      SELECT region, start_date, timezone, user_id, username, description
        FROM calendar_events
       WHERE topic_id = :topic_id
         AND post_id IS NULL
         AND start_date >= :start_date
       ORDER BY region, start_date
    SQL

    DB
      .query(grouped_sql, topic_id: object.topic_id, start_date: start_date)
      .each do |row|
        identifier = "#{row.region.split("_").first}-#{row.start_date.strftime("%Y-%j")}"

        grouped[identifier] ||= {
          type: :grouped,
          from: row.start_date,
          timezone: row.timezone,
          name: [],
          users: [],
        }

        grouped[identifier][:name] << row.description
        grouped[identifier][:users] << { username: row.username, timezone: timezones[row.user_id] }
      end

    grouped.each do |_, v|
      v[:name].uniq!
      v[:name].sort!
      v[:name] = v[:name].join(", ")
      v[:users].uniq! { |u| u[:username] }
      v[:users].sort! { |a, b| a[:username] <=> b[:username] }
    end

    standalones + grouped.values
  end

  add_to_serializer(
    :post,
    :group_timezones,
    include_condition: -> do
      post_custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD].present?
    end,
  ) do
    result = {}
    group_timezones = post_custom_fields[DiscourseCalendar::GROUP_TIMEZONES_CUSTOM_FIELD] || {}
    group_names = group_timezones["groups"] || []

    if group_names.present?
      users =
        User
          .human_users
          .joins(:groups, :user_option)
          .where("groups.name": group_names)
          .select("users.*", "groups.name AS group_name", "user_options.timezone")

      usernames_on_holiday = DiscourseCalendar.users_on_holiday

      users.each do |u|
        result[u.group_name] ||= []
        result[u.group_name] << UserTimezoneSerializer.new(
          u,
          root: false,
          on_holiday: usernames_on_holiday&.include?(u.username),
        ).as_json
      end
    end

    result
  end

  add_to_serializer(:site, :users_on_holiday, include_condition: -> { scope.is_staff? }) do
    DiscourseCalendar.users_on_holiday
  end

  on(:reduce_cooked) do |fragment, post|
    if SiteSetting.discourse_post_event_enabled
      fragment
        .css(".discourse-post-event")
        .each do |event_node|
          starts_at = event_node["data-start"]
          ends_at = event_node["data-end"]
          dates = "#{starts_at} (#{event_node["data-timezone"] || "UTC"})"
          dates = "#{dates} → #{ends_at} (#{event_node["data-timezone"] || "UTC"})" if ends_at

          event_name = event_node["data-name"] || post.topic.title
          event_node.replace <<~TXT
          <div style='border:1px solid #dedede'>
            <p><a href="#{Discourse.base_url}#{post.url}">#{CGI.escape_html(event_name)}</a></p>
            <p>#{CGI.escape_html(dates)}</p>
          </div>
        TXT
        end
    end
  end

  on(:user_destroyed) { |user| DiscoursePostEvent::Invitee.where(user_id: user.id).destroy_all }

  if respond_to?(:add_post_revision_notifier_recipients)
    add_post_revision_notifier_recipients do |post_revision|
      # next if no modifications
      next if !post_revision.modifications.present?

      # do no notify recipients when only updating tags
      next if post_revision.modifications.keys == ["tags"]

      ids = []
      post = post_revision.post

      if post && post.is_first_post? && post.event
        ids.concat(post.event.on_going_event_invitees.pluck(:user_id))
      end

      ids
    end
  end

  on(:site_setting_changed) do |name, old_val, new_val|
    next if name != :discourse_post_event_allowed_custom_fields

    previous_fields = old_val.split("|")
    new_fields = new_val.split("|")
    removed_fields = previous_fields - new_fields

    next if removed_fields.empty?

    DiscoursePostEvent::Event.all.find_each do |event|
      removed_fields.each { |field| event.custom_fields.delete(field) }
      event.save
    end
  end

  if defined?(DiscourseAutomation)
    on(:discourse_post_event_event_started) do |event|
      DiscourseAutomation::Automation
        .where(enabled: true, trigger: "event_started")
        .each do |automation|
          fields = automation.serialized_fields
          topic_id = fields.dig("topic_id", "value")

          next unless event.post.topic.id.to_s == topic_id

          automation.trigger!(
            "kind" => "event_started",
            "event" => event,
            "placeholders" => {
              "event_url" => event.url,
            },
          )
        end
    end

    add_triggerable_to_scriptable("event_started", "send_chat_message")

    add_automation_triggerable("event_started") do
      placeholder :event_url

      field :topic_id, component: :text
    end
  end

  query =
    Proc.new do |notifications, data|
      notifications.where("data::json ->> 'topic_title' = ?", data[:topic_title].to_s).where(
        "data::json ->> 'message' = ?",
        data[:message].to_s,
      )
    end

  reminders_consolidation_plan =
    Notifications::DeletePreviousNotifications.new(
      type: Notification.types[:event_reminder],
      previous_query_blk: query,
    )

  invitation_consolidation_plan =
    Notifications::DeletePreviousNotifications.new(
      type: Notification.types[:event_invitation],
      previous_query_blk: query,
    )

  register_notification_consolidation_plan(reminders_consolidation_plan)
  register_notification_consolidation_plan(invitation_consolidation_plan)

  Report.add_report("currently_away") do |report|
    group_filter = report.filters.dig(:group) || Group::AUTO_GROUPS[:staff]
    report.add_filter("group", type: "group", default: group_filter)

    break unless group = Group.find_by(id: group_filter)

    report.labels = [
      { property: :username, title: I18n.t("reports.currently_away.labels.username") },
    ]

    group_usernames = group.users.pluck(:username)
    on_holiday_usernames = DiscourseCalendar.users_on_holiday
    report.data = (group_usernames & on_holiday_usernames).map { |username| { username: username } }
    report.total = report.data.count
  end
end
