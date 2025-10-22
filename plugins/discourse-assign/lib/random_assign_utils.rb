# frozen_string_literal: true

class RandomAssignUtils
  attr_reader :context, :fields, :automation, :topic, :group

  def self.automation_script!(...)
    new(...).automation_script!
  end

  def initialize(context, fields, automation)
    @context = context
    @fields = fields
    @automation = automation

    raise_error("discourse-assign is not enabled") unless SiteSetting.assign_enabled?
    unless topic_id = fields.dig("assigned_topic", "value")
      raise_error("`assigned_topic` not provided")
    end
    unless @topic = Topic.find_by(id: topic_id)
      raise_error("Topic(#{topic_id}) not found")
    end

    unless group_id = fields.dig("assignees_group", "value")
      raise_error("`assignees_group` not provided")
    end
    unless @group = Group.find_by(id: group_id)
      raise_error("Group(#{group_id}) not found")
    end
  end

  def automation_script!
    return log_info("Topic(#{topic.id}) has already been assigned recently") if assigned_recently?
    return no_one! unless assigned_user
    assign_user!
  end

  def recently_assigned_users_ids(from)
    usernames =
      PostCustomField
        .joins(:post)
        .where(
          name: "action_code_who",
          posts: {
            topic: topic,
            action_code: %w[assigned reassigned assigned_to_post],
          },
        )
        .where("posts.created_at > ?", from)
        .order("posts.created_at DESC")
        .pluck(:value)
        .uniq
    User
      .where(username: usernames)
      .joins(
        "JOIN unnest('{#{usernames.join(",")}}'::text[]) WITH ORDINALITY t(username, ord) USING(username)",
      )
      .limit(100)
      .order("ord")
      .pluck(:id)
  end

  private

  def assigned_user
    @assigned_user ||=
      begin
        group_users_ids = group_users.pluck(:id)
        return if group_users_ids.empty?

        last_assignees_ids = recently_assigned_users_ids(max_recently_assigned_days)
        users_ids = group_users_ids - last_assignees_ids
        if users_ids.blank?
          recently_assigned_users_ids = recently_assigned_users_ids(min_recently_assigned_days)
          users_ids = group_users_ids - recently_assigned_users_ids
        end
        users_ids << last_assignees_ids.intersection(group_users_ids).last if users_ids.blank?
        if fields.dig("in_working_hours", "value")
          assign_to_user_id = users_ids.shuffle.detect { |user_id| in_working_hours?(user_id) }
        end
        assign_to_user_id ||= users_ids.sample

        User.find(assign_to_user_id)
      end
  end

  def assign_user!
    return create_post_template if post_template
    Assigner
      .new(topic, Discourse.system_user)
      .assign(assigned_user, allow_self_reassign: true)
      .then do |result|
        next if result[:success]
        no_one!
      end
  end

  def create_post_template
    post =
      PostCreator.new(
        Discourse.system_user,
        raw: post_template,
        skip_validations: true,
        topic_id: topic.id,
      ).create!
    Assigner
      .new(post, Discourse.system_user)
      .assign(assigned_user, allow_self_reassign: true)
      .then do |result|
        next if result[:success]
        PostDestroyer.new(Discourse.system_user, post).destroy
        no_one!
      end
  end

  def group_users
    users =
      group
        .users
        .where(id: User.assign_allowed.select(:id))
        .where.not(
          id:
            User
              .joins(:_custom_fields)
              .where(user_custom_fields: { name: "on_holiday", value: "t" })
              .select(:id),
        )
    return users unless skip_new_users_for_days
    users.where("users.created_at < ?", skip_new_users_for_days)
  end

  def raise_error(message)
    raise("[discourse-automation id=#{automation.id}] #{message}.")
  end

  def log_info(message)
    Rails.logger.info("[discourse-automation id=#{automation.id}] #{message}.")
  end

  def no_one!
    PostCreator.create!(
      Discourse.system_user,
      topic_id: topic.id,
      raw: I18n.t("discourse_automation.scriptables.random_assign.no_one", group: group.name),
      validate: false,
    )
  end

  def assigned_recently?
    return unless min_hours
    TopicCustomField
      .where(name: "assigned_to_id", topic: topic)
      .where("created_at < ?", min_hours)
      .exists?
  end

  def skip_new_users_for_days
    days = fields.dig("skip_new_users_for_days", "value").presence
    return unless days
    days.to_i.days.ago
  end

  def max_recently_assigned_days
    @max_days ||= (fields.dig("max_recently_assigned_days", "value").presence || 180).to_i.days.ago
  end

  def min_recently_assigned_days
    @min_days ||= (fields.dig("min_recently_assigned_days", "value").presence || 14).to_i.days.ago
  end

  def post_template
    @post_template ||= fields.dig("post_template", "value").presence
  end

  def min_hours
    hours = fields.dig("minimum_time_between_assignments", "value").presence
    return unless hours
    hours.to_i.hours.ago
  end

  def in_working_hours?(user_id)
    tzinfo = user_tzinfo(user_id)
    tztime = tzinfo.now

    !tztime.saturday? && !tztime.sunday? && tztime.hour > 7 && tztime.hour < 11
  end

  def user_tzinfo(user_id)
    timezone = UserOption.where(user_id: user_id).pluck(:timezone).first || "UTC"

    tzinfo = nil
    begin
      tzinfo = ActiveSupport::TimeZone.find_tzinfo(timezone)
    rescue TZInfo::InvalidTimezoneIdentifier
      Rails.logger.warn(
        "#{User.find_by(id: user_id)&.username} has the timezone #{timezone} set, we do not know how to parse it in Rails (assuming UTC)",
      )
      timezone = "UTC"
      tzinfo = ActiveSupport::TimeZone.find_tzinfo(timezone)
    end

    tzinfo
  end
end
