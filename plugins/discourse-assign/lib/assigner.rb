# frozen_string_literal: true

require "email/sender"
require "nokogiri"

class ::Assigner
  ASSIGNMENTS_PER_TOPIC_LIMIT = 5

  def self.backfill_auto_assign
    staff_mention =
      User
        .assign_allowed
        .pluck("username")
        .map { |name| "p.cooked ILIKE '%mention%@#{name}%'" }
        .join(" OR ")

    sql = <<~SQL
      SELECT p.topic_id, MAX(post_number) post_number
        FROM posts p
        JOIN topics t ON t.id = p.topic_id
        LEFT JOIN assignments a ON a.target_id = p.topic_id AND a.target_type = 'Topic'
       WHERE p.user_id IN (SELECT id FROM users WHERE moderator OR admin)
         AND (#{staff_mention})
         AND a.assigned_to_id IS NULL
         AND NOT t.closed
         AND t.deleted_at IS NULL
       GROUP BY p.topic_id
    SQL

    puts
    assigned = 0

    ActiveRecord::Base
      .connection
      .raw_connection
      .exec(sql)
      .to_a
      .each do |row|
        post = Post.find_by(post_number: row["post_number"].to_i, topic_id: row["topic_id"].to_i)
        assigned += 1 if post && auto_assign(post)
        putc "."
      end

    puts
    puts "#{assigned} topics where automatically assigned to staff members"
  end

  def self.assigned_self?(text)
    return false if text.blank? || SiteSetting.assign_self_regex.blank?
    regex =
      begin
        Regexp.new(SiteSetting.assign_self_regex)
      rescue StandardError
        nil
      end
    !!(regex && text[regex])
  end

  def self.assigned_other?(text)
    return false if text.blank? || SiteSetting.assign_other_regex.blank?
    regex =
      begin
        Regexp.new(SiteSetting.assign_other_regex)
      rescue StandardError
        nil
      end
    !!(regex && text[regex])
  end

  def self.auto_assign(post, force: false)
    return unless SiteSetting.assigns_by_staff_mention

    if post.user && post.topic && post.user.can_assign?
      return if post.topic.assignment.present? && !force

      # remove quotes, oneboxes and code blocks
      doc = Nokogiri::HTML5.fragment(post.cooked)
      doc.css(".quote, .onebox, pre, code").remove
      text = doc.text.strip

      assign_other = assigned_other?(text) && mentioned_staff(post)
      assign_self = assigned_self?(text) && post.user
      return unless assign_other || assign_self

      if is_last_staff_post?(post)
        assigner = new(post.topic, post.user)
        if assign_other
          assigner.assign(assign_other, skip_small_action_post: true)
        elsif assign_self
          assigner.assign(assign_self, skip_small_action_post: true)
        end
      end
    end
  end

  def self.is_last_staff_post?(post)
    allowed_user_ids = User.assign_allowed.pluck(:id).join(",")

    sql = <<~SQL
      SELECT 1
        FROM posts p
        JOIN users u ON u.id = p.user_id
       WHERE p.deleted_at IS NULL
         AND p.topic_id = :topic_id
         AND u.id IN (#{allowed_user_ids})
      HAVING MAX(post_number) = :post_number
    SQL

    args = { topic_id: post.topic_id, post_number: post.post_number }

    DB.exec(sql, args) == 1
  end

  def self.mentioned_staff(post)
    mentions = post.raw_mentions
    if mentions.present?
      User.human_users.assign_allowed.where("username_lower IN (?)", mentions.map(&:downcase)).first
    end
  end

  def self.publish_topic_tracking_state(topic, user_id)
    if topic.private_message?
      MessageBus.publish("/private-messages/assigned", { topic_id: topic.id }, user_ids: [user_id])
    end
  end

  def initialize(target, user)
    @assigned_by = user
    @target = target
  end

  def allowed_user_ids
    @allowed_user_ids ||= User.assign_allowed.pluck(:id)
  end

  def allowed_group_ids
    @allowed_group_ids ||= Group.assignable(@assigned_by).pluck(:id)
  end

  def can_assign_to?(assign_to)
    return true if assign_to.is_a?(Group)
    return true if @assigned_by.id == assign_to.id

    assigned_total =
      Assignment
        .joins_with_topics
        .where(topics: { deleted_at: nil })
        .where(assigned_to_id: assign_to.id, active: true)
        .count

    assigned_total < SiteSetting.max_assigned_topics
  end

  def can_be_assigned?(assign_to)
    if assign_to.is_a?(User)
      allowed_user_ids.include?(assign_to.id)
    else
      allowed_group_ids.include?(assign_to.id)
    end
  end

  def topic_target?
    @topic_target ||= @target.is_a?(Topic)
  end

  def post_target?
    @post_target ||= @target.is_a?(Post)
  end

  def private_message_allowed_user_ids
    @private_message_allowed_user_ids ||= topic.all_allowed_users.pluck(:id)
  end

  def can_assignee_see_target?(assignee)
    if (topic_target? || post_target?) && topic.private_message? &&
         !private_message_allowed_user_ids.include?(assignee.id)
      return false
    end
    return Guardian.new(assignee).can_see_topic?(@target) if topic_target?
    return Guardian.new(assignee).can_see_post?(@target) if post_target?

    raise Discourse::InvalidAccess
  end

  def topic
    return @topic if @topic
    @topic = @target if topic_target?
    @topic = @target.topic if post_target?

    raise Discourse::InvalidParameters if !@topic
    @topic
  end

  def first_post
    topic.posts.where(post_number: 1).first
  end

  def forbidden_reasons(assign_to:, type:, note:, status:, allow_self_reassign:)
    case
    when assign_to.is_a?(User) && !can_assignee_see_target?(assign_to)
      if topic.private_message?
        :forbidden_assignee_not_pm_participant
      else
        :forbidden_assignee_cant_see_topic
      end
    when assign_to.is_a?(Group) && assign_to.users.any? { |user| !can_assignee_see_target?(user) }
      if topic.private_message?
        :forbidden_group_assignee_not_pm_participant
      else
        :forbidden_group_assignee_cant_see_topic
      end
    when !can_be_assigned?(assign_to)
      assign_to.is_a?(User) ? :forbidden_assign_to : :forbidden_group_assign_to
    when !allow_self_reassign && already_assigned?(assign_to, type, note, status)
      assign_to.is_a?(User) ? :already_assigned : :group_already_assigned
    when Assignment.where(topic: topic, active: true).count >= ASSIGNMENTS_PER_TOPIC_LIMIT &&
           !reassign?
      :too_many_assigns_for_topic
    when !can_assign_to?(assign_to)
      :too_many_assigns
    end
  end

  def update_details(assign_to, note, status, skip_small_action_post: false, should_notify: true)
    case
    when note.present? && status.present? && @target.assignment.note != note &&
           @target.assignment.status != status
      small_action_text = <<~TEXT
        Status: #{@target.assignment.status} → #{status}

        #{note}
      TEXT
      change_type = "details"
    when note.present? && @target.assignment.note != note
      small_action_text = note
      change_type = "note"
    when @target.assignment.status != status
      small_action_text = "#{@target.assignment.status} → #{status}"
      change_type = "status"
    end

    @target.assignment.update!(note: note, status: status)
    queue_notification(@target.assignment) if should_notify
    publish_assignment(@target.assignment, assign_to, note, status)

    # email is skipped, for now

    unless skip_small_action_post
      action_code = "#{change_type}_change"
      add_small_action_post(action_code, assign_to, small_action_text)
    end

    { success: true }
  end

  def assign(
    assign_to,
    note: nil,
    skip_small_action_post: false,
    status: nil,
    allow_self_reassign: false,
    should_notify: true
  )
    assigned_to_type = assign_to.is_a?(User) ? "User" : "Group"

    if topic.private_message? && SiteSetting.invite_on_assign
      if assigned_to_type == "Group"
        invite_group(assign_to, should_notify)
      else
        invite_user(assign_to)
      end
    end

    forbidden_reason =
      forbidden_reasons(
        assign_to: assign_to,
        type: assigned_to_type,
        note: note,
        status: status,
        allow_self_reassign: allow_self_reassign,
      )
    return { success: false, reason: forbidden_reason } if forbidden_reason

    if no_assignee_change?(assign_to) && details_change?(note, status)
      return(
        update_details(
          assign_to,
          note,
          status,
          skip_small_action_post: skip_small_action_post,
          should_notify: should_notify,
        )
      )
    end

    action_code = {}
    action_code[:user] = topic.assignment.present? ? "reassigned" : "assigned"
    action_code[:group] = topic.assignment.present? ? "reassigned_group" : "assigned_group"

    skip_small_action_post =
      skip_small_action_post || (!allow_self_reassign && no_assignee_change?(assign_to))

    if @target.assignment
      Jobs.enqueue(
        :unassign_notification,
        topic_id: topic.id,
        assigned_to_id: @target.assignment.assigned_to_id,
        assigned_to_type: @target.assignment.assigned_to_type,
        assignment_id: @target.assignment.id,
      )
      @target.assignment.destroy!
    end

    assignment =
      @target.create_assignment!(
        assigned_to: assign_to,
        assigned_by_user: @assigned_by,
        topic: topic,
        note: note,
        status: status,
      )

    first_post.publish_change_to_clients!(:revised, reload_topic: true)
    queue_notification(assignment) if should_notify

    # This assignment should never be notified
    SilencedAssignment.create!(assignment_id: assignment.id) if !should_notify

    publish_assignment(assignment, assign_to, note, status)

    if assignment.assigned_to_user?
      if !assign_to.user_option.do_nothing_when_assigned?
        notification_level =
          if assign_to.user_option.track_topic_when_assigned?
            TopicUser.notification_levels[:tracking]
          else
            TopicUser.notification_levels[:watching]
          end

        topic_user = TopicUser.find_by(user_id: assign_to.id, topic:)
        if !topic_user || topic_user.notification_level < notification_level
          notifications_reason_id = TopicUser.notification_reasons[:plugin_changed]
          TopicUser.change(assign_to.id, topic.id, notification_level:, notifications_reason_id:)
        end
      end

      if SiteSetting.assign_mailer == AssignMailer.levels[:always] ||
           (
             SiteSetting.assign_mailer == AssignMailer.levels[:different_users] &&
               @assigned_by.id != assign_to.id
           )
        if !topic.muted?(assign_to)
          message = AssignMailer.send_assignment(assign_to.email, topic, @assigned_by)
          Email::Sender.new(message, :assign_message).send
        end
      end
    end

    unless skip_small_action_post
      post_action_code = moderator_post_assign_action_code(assignment, action_code)
      add_small_action_post(post_action_code, assign_to, note)
    end

    # Create a webhook event
    if WebHook.active_web_hooks(:assigned).exists?
      assigned_to_type = :assigned
      payload = {
        type: assigned_to_type,
        topic_id: topic.id,
        topic_title: topic.title,
        assigned_by_id: @assigned_by.id,
        assigned_by_username: @assigned_by.username,
      }
      if assignment.assigned_to_user?
        payload.merge!({ assigned_to_id: assign_to.id, assigned_to_username: assign_to.username })
      else
        payload.merge!(
          { assigned_to_group_id: assign_to.id, assigned_to_group_name: assign_to.name },
        )
      end
      WebHook.enqueue_assign_hooks(assigned_to_type, payload.to_json)
    end

    { success: true }
  end

  def unassign(silent: false, deactivate: false)
    if assignment = @target.assignment
      deactivate ? assignment.update!(active: false) : assignment.destroy!

      return if first_post.blank?

      first_post.publish_change_to_clients!(:revised, reload_topic: true)

      Jobs.enqueue(
        :unassign_notification,
        topic_id: topic.id,
        assigned_to_id: assignment.assigned_to.id,
        assigned_to_type: assignment.assigned_to_type,
        assignment_id: assignment.id,
      )

      assigned_to = assignment.assigned_to

      if SiteSetting.unassign_creates_tracking_post && !silent
        post_type = SiteSetting.assigns_public ? Post.types[:small_action] : Post.types[:whisper]

        custom_fields = small_action_username_or_name(assigned_to)

        if post_target?
          custom_fields.merge!("action_code_path" => "/p/#{@target.id}")
          custom_fields.merge!("action_code_post_id" => @target.id)
        end

        topic.add_moderator_post(
          @assigned_by,
          nil,
          bump: false,
          post_type: post_type,
          custom_fields: custom_fields,
          action_code: moderator_post_unassign_action_code(assignment),
        )
      end

      # Create a webhook event
      if WebHook.active_web_hooks(:unassigned).exists?
        type = :unassigned
        payload = {
          type: type,
          topic_id: topic.id,
          topic_title: topic.title,
          unassigned_by_id: @assigned_by.id,
          unassigned_by_username: @assigned_by.username,
        }
        if assignment.assigned_to_user?
          payload.merge!(
            { unassigned_to_id: assigned_to.id, unassigned_to_username: assigned_to.username },
          )
        else
          payload.merge!(
            { unassigned_to_group_id: assigned_to.id, unassigned_to_group_name: assigned_to.name },
          )
        end
        WebHook.enqueue_assign_hooks(type, payload.to_json)
      end

      MessageBus.publish(
        "/staff/topic-assignment",
        {
          type: "unassigned",
          topic_id: topic.id,
          post_id: post_target? && @target.id,
          post_number: post_target? && @target.post_number,
          assigned_type: assignment.assigned_to.is_a?(User) ? "User" : "Group",
          assignment_note: nil,
          assignment_status: nil,
        },
        user_ids: allowed_user_ids,
      )
    end
  end

  private

  def invite_user(user)
    return if topic.all_allowed_users.exists?(id: user.id)

    guardian.ensure_can_invite_to!(topic)
    topic.invite(@assigned_by, user.username)
  end

  def invite_group(group, should_notify)
    return if topic.topic_allowed_groups.exists?(group_id: group.id)
    if topic
         .all_allowed_users
         .joins("RIGHT JOIN group_users ON group_users.user_id = users.id")
         .where("group_users.group_id = ? AND users.id IS NULL", group.id)
         .empty?
      return # all group members can already see the topic
    end

    guardian.ensure_can_invite_group_to_private_message!(group, topic)
    topic.invite_group(@assigned_by, group, should_notify: should_notify)
  end

  def guardian
    @guardian ||= Guardian.new(@assigned_by)
  end

  def queue_notification(assignment)
    Jobs.enqueue(:assign_notification, assignment_id: assignment.id)
  end

  def small_action_username_or_name(assign_to)
    if (assign_to.is_a?(User) && SiteSetting.prioritize_full_name_in_ux) ||
         !assign_to.try(:username)
      custom_fields = { "action_code_who" => assign_to.name || assign_to.username }
    else
      custom_fields = {
        "action_code_who" => assign_to.is_a?(User) ? assign_to.username : assign_to.name,
      }
    end
    custom_fields
  end

  def add_small_action_post(action_code, assign_to, text)
    custom_fields = small_action_username_or_name(assign_to)

    if post_target?
      custom_fields.merge!(
        { "action_code_path" => "/p/#{@target.id}", "action_code_post_id" => @target.id },
      )
    end

    topic.add_moderator_post(
      @assigned_by,
      text,
      bump: false,
      auto_track: false,
      post_type: SiteSetting.assigns_public ? Post.types[:small_action] : Post.types[:whisper],
      action_code: action_code,
      custom_fields: custom_fields,
    )
  end

  def publish_assignment(assignment, assign_to, note, status)
    serializer = assignment.assigned_to_user? ? BasicUserSerializer : BasicGroupSerializer
    MessageBus.publish(
      "/staff/topic-assignment",
      {
        type: "assigned",
        topic_id: topic.id,
        post_id: post_target? && @target.id,
        post_number: post_target? && @target.post_number,
        assigned_type: assignment.assigned_to_type,
        assigned_to: serializer.new(assign_to, scope: Guardian.new, root: false).as_json,
        assignment_note: note,
        assignment_status: status,
      },
      user_ids: allowed_user_ids,
    )
  end

  def moderator_post_assign_action_code(assignment, action_code)
    if assignment.target.is_a?(Post)
      # posts do not have to handle conditions of 'assign' or 'reassign'
      assignment.assigned_to_user? ? "assigned_to_post" : "assigned_group_to_post"
    elsif assignment.target.is_a?(Topic)
      assignment.assigned_to_user? ? "#{action_code[:user]}" : "#{action_code[:group]}"
    end
  end

  def moderator_post_unassign_action_code(assignment)
    suffix =
      if assignment.target.is_a?(Post)
        "_from_post"
      elsif assignment.target.is_a?(Topic)
        ""
      end
    return "unassigned#{suffix}" if assignment.assigned_to_user?
    "unassigned_group#{suffix}" if assignment.assigned_to_group?
  end

  def already_assigned?(assign_to, type, note, status)
    assignment_eq?(@target.assignment, assign_to, type, note, status)
  end

  def reassign?
    Assignment.exists?(target: @target, active: true)
  end

  def no_assignee_change?(assignee)
    @target.assignment&.assigned_to_id == assignee.id
  end

  def details_change?(note, status)
    note.present? || @target.assignment&.status != status
  end

  def assignment_eq?(assignment, assign_to, type, note, status)
    return false if !assignment&.active
    return false if assignment.assigned_to_id != assign_to.id
    return false if assignment.assigned_to_type != type
    return false if assignment.note != note
    assignment.status == status || !status && assignment.status == Assignment.default_status
  end
end
