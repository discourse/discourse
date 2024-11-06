# frozen_string_literal: true

require "edit_rate_limiter"
require "post_locker"

class PostRevisor
  # Helps us track changes to a topic.
  #
  # It's passed to `track_topic_fields` callbacks so they can record if they
  # changed a value or not. This is needed for things like custom fields.
  class TopicChanges
    attr_reader :topic, :user

    def initialize(topic, user)
      @topic = topic
      @user = user
      @changed = {}
      @errored = false
    end

    def errored?
      @errored
    end

    def guardian
      @guardian ||= Guardian.new(@user)
    end

    def record_change(field_name, previous_val, new_val)
      return if previous_val == new_val
      diff[field_name] = [previous_val, new_val]
    end

    def check_result(res)
      @errored = true if !res
    end

    def diff
      @diff ||= {}
    end
  end

  POST_TRACKED_FIELDS = %w[raw cooked edit_reason user_id wiki post_type]

  attr_reader :category_changed, :post_revision

  def initialize(post, topic = post.topic)
    @post = post
    @topic = topic

    # Make sure we have only one Topic instance
    post.topic = topic
  end

  def self.tracked_topic_fields
    @@tracked_topic_fields ||= {}
    @@tracked_topic_fields
  end

  def self.track_topic_field(field, &block)
    tracked_topic_fields[field] = block

    # Define it in the serializer unless it already has been defined
    if PostRevisionSerializer.instance_methods(false).exclude?("#{field}_changes".to_sym)
      PostRevisionSerializer.add_compared_field(field)
    end
  end

  def self.track_and_revise(topic_changes, field, attribute)
    topic_changes.record_change(field, topic_changes.topic.public_send(field), attribute)
    topic_changes.topic.public_send("#{field}=", attribute)
  end

  track_topic_field(:title) do |topic_changes, attribute|
    track_and_revise topic_changes, :title, attribute
  end

  track_topic_field(:archetype) do |topic_changes, attribute|
    track_and_revise topic_changes, :archetype, attribute
  end

  track_topic_field(:category_id) do |tc, new_category_id, fields|
    current_category = tc.topic.category
    new_category =
      (new_category_id.nil? || new_category_id.zero?) ? nil : Category.find(new_category_id)

    if new_category.nil? && tc.topic.private_message?
      tc.record_change("category_id", current_category.id, nil)
      tc.topic.category_id = nil
    elsif new_category.nil? || tc.guardian.can_move_topic_to_category?(new_category_id)
      tags = fields[:tags] || tc.topic.tags.map(&:name)
      if new_category &&
           !DiscourseTagging.validate_category_tags(tc.guardian, tc.topic, new_category, tags)
        tc.check_result(false)
        next
      end

      tc.record_change("category_id", current_category&.id, new_category&.id)
      tc.check_result(tc.topic.change_category_to_id(new_category_id))
      create_small_action_for_category_change(
        topic: tc.topic,
        user: tc.user,
        old_category: current_category,
        new_category: new_category,
      )
    end
  end

  track_topic_field(:tags) do |tc, tags|
    if tc.guardian.can_tag_topics?
      prev_tags = tc.topic.tags.map(&:name)
      next if tags.blank? && prev_tags.blank?
      if !DiscourseTagging.tag_topic_by_names(tc.topic, tc.guardian, tags)
        tc.check_result(false)
        next
      end
      if prev_tags.sort != tags.sort
        tc.record_change("tags", prev_tags, tags)
        DB.after_commit do
          post = tc.topic.ordered_posts.first
          notified_user_ids = [post.user_id, post.last_editor_id].uniq

          added_tags = tags - prev_tags
          removed_tags = prev_tags - tags

          if !SiteSetting.disable_tags_edit_notifications
            Jobs.enqueue(
              :notify_tag_change,
              post_id: post.id,
              notified_user_ids: notified_user_ids,
              diff_tags: (added_tags | removed_tags),
            )
          end

          create_small_action_for_tag_changes(
            topic: tc.topic,
            user: tc.user,
            added_tags: added_tags,
            removed_tags: removed_tags,
          )
        end
      end
    end
  end

  track_topic_field(:featured_link) do |topic_changes, featured_link|
    if !SiteSetting.topic_featured_link_enabled ||
         !topic_changes.guardian.can_edit_featured_link?(topic_changes.topic.category_id)
      topic_changes.check_result(false)
    else
      topic_changes.record_change("featured_link", topic_changes.topic.featured_link, featured_link)
      topic_changes.topic.featured_link = featured_link
    end
  end

  def self.create_small_action_for_category_change(topic:, user:, old_category:, new_category:)
    if !old_category || !new_category || !SiteSetting.create_post_for_category_and_tag_changes ||
         SiteSetting.whispers_allowed_groups.blank?
      return
    end

    topic.add_moderator_post(
      user,
      I18n.t(
        "topic_category_changed",
        from: "##{old_category.slug_ref}",
        to: "##{new_category.slug_ref}",
      ),
      post_type: Post.types[:whisper],
      action_code: "category_changed",
    )
  end

  def self.create_small_action_for_tag_changes(topic:, user:, added_tags:, removed_tags:)
    if !SiteSetting.create_post_for_category_and_tag_changes ||
         SiteSetting.whispers_allowed_groups.blank?
      return
    end

    topic.add_moderator_post(
      user,
      tags_changed_raw(added: added_tags, removed: removed_tags),
      post_type: Post.types[:whisper],
      action_code: "tags_changed",
      custom_fields: {
        tags_added: added_tags,
        tags_removed: removed_tags,
      },
    )
  end

  def self.tags_changed_raw(added:, removed:)
    if removed.present? && added.present?
      I18n.t(
        "topic_tag_changed.added_and_removed",
        added: tag_list_to_raw(added),
        removed: tag_list_to_raw(removed),
      )
    elsif added.present?
      I18n.t("topic_tag_changed.added", added: tag_list_to_raw(added))
    elsif removed.present?
      I18n.t("topic_tag_changed.removed", removed: tag_list_to_raw(removed))
    end
  end

  def self.tag_list_to_raw(tag_list)
    tag_list.sort.map { |tag_name| "##{tag_name}" }.join(", ")
  end

  # AVAILABLE OPTIONS:
  # - revised_at: changes the date of the revision
  # - force_new_version: bypass grace period edit window
  # - bypass_rate_limiter:
  # - bypass_bump: do not bump the topic, even if last post
  # - skip_validations: ask ActiveRecord to skip validations
  # - skip_revision: do not create a new PostRevision record
  # - skip_staff_log: skip creating an entry in the staff action log
  def revise!(editor, fields, opts = {})
    @editor = editor
    @fields = fields.with_indifferent_access
    @opts = opts

    @topic_changes = TopicChanges.new(@topic, editor)

    # some normalization
    @fields[:raw] = cleanup_whitespaces(@fields[:raw]) if @fields.has_key?(:raw)
    @fields[:user_id] = @fields[:user_id].to_i if @fields.has_key?(:user_id)
    @fields[:category_id] = @fields[:category_id].to_i if @fields.has_key?(:category_id)

    # always reset edit_reason unless provided, do not set to nil else
    # previous reasons are lost
    @fields.delete(:edit_reason) if @fields[:edit_reason].blank?

    Post.plugin_permitted_update_params.each do |field, val|
      val[:handler].call(@post, @fields[field]) if @fields.key?(field) && val[:plugin].enabled?
    end

    if !should_revise?
      # the draft sequence is advanced here to handle the edge case where a
      # user opens the composer to edit a post and makes some changes (which
      # saves a draft), but then un-does the changes and clicks save. In this
      # case, should_revise? returns false because nothing has really changed
      # in the post, but we want to get rid of the draft so we advance the
      # sequence.
      advance_draft_sequence if !opts[:keep_existing_draft]
      return false
    end

    @post.acting_user = @editor
    @topic.acting_user = @editor
    @revised_at = @opts[:revised_at] || Time.now
    @last_version_at = @post.last_version_at || Time.now

    if guardian.affected_by_slow_mode?(@topic) && !grace_period_edit? &&
         SiteSetting.slow_mode_prevents_editing
      @post.errors.add(:base, I18n.t("cannot_edit_on_slow_mode"))
      return false
    end

    @version_changed = false
    @post_successfully_saved = true

    @validate_post = true
    @validate_post = @opts[:validate_post] if @opts.has_key?(:validate_post)
    @validate_post = !@opts[:skip_validations] if @opts.has_key?(:skip_validations)

    @validate_topic = true
    @validate_topic = @opts[:validate_topic] if @opts.has_key?(:validate_topic)
    @validate_topic = !@opts[:skip_validations] if @opts.has_key?(:skip_validations)

    @skip_revision = false
    @skip_revision = @opts[:skip_revision] if @opts.has_key?(:skip_revision)

    @post.incoming_email&.update(imap_sync: true) if @post.incoming_email&.imap_uid

    old_raw = @post.raw

    Post.transaction do
      revise_post

      yield if block_given?
      # TODO: these callbacks are being called in a transaction
      # it is kind of odd, because the callback is called "before_edit"
      # but the post is already edited at this point
      # Trouble is that much of the logic of should I edit? is deeper
      # down so yanking this in front of the transaction will lead to
      # false positive.
      plugin_callbacks

      revise_topic
      advance_draft_sequence if !opts[:keep_existing_draft]
    end

    # bail out if the post or topic failed to save
    return false if !successfully_saved_post_and_topic

    # Lock the post by default if the appropriate setting is true
    if (
         SiteSetting.staff_edit_locks_post? && !@post.wiki? && @fields.has_key?("raw") &&
           @editor.staff? && @editor != Discourse.system_user && !@post.user&.staff?
       )
      PostLocker.new(@post, @editor).lock
    end

    # We log staff/group moderator edits to posts
    if (
         (
           @editor.staff? ||
             (
               @post.is_category_description? &&
                 guardian.can_edit_category_description?(@post.topic.category)
             )
         ) && @editor.id != @post.user_id && @fields.has_key?("raw") && !@opts[:skip_staff_log]
       )
      StaffActionLogger.new(@editor).log_post_edit(@post, old_raw: old_raw)
    end

    # WARNING: do not pull this into the transaction
    # it can fire events in sidekiq before the post is done saving
    # leading to corrupt state
    QuotedPost.extract_from(@post)
    TopicLink.extract_from(@post)

    Topic.reset_highest(@topic.id)

    post_process_post
    alert_users
    publish_changes
    grant_badge

    ReviewablePost.queue_for_review_if_possible(@post, @editor) if should_create_new_version?

    successfully_saved_post_and_topic
  end

  def cleanup_whitespaces(raw)
    raw.present? ? TextCleaner.normalize_whitespaces(raw).rstrip : ""
  end

  def should_revise?
    post_changed? || topic_changed?
  end

  def post_changed?
    POST_TRACKED_FIELDS.each do |field|
      return true if @fields.has_key?(field) && @fields[field] != @post.public_send(field)
    end
    false
  end

  def topic_changed?
    PostRevisor.tracked_topic_fields.keys.any? { |f| @fields.has_key?(f) }
  end

  def revise_post
    if should_create_new_version?
      revise_and_create_new_version
    else
      unless cached_original_raw
        self.original_raw = @post.raw
        self.original_cooked = @post.cooked
      end
      revise
    end
  end

  def should_create_new_version?
    return false if @skip_revision
    edited_by_another_user? || flagged? || !grace_period_edit? || owner_changed? ||
      force_new_version? || edit_reason_specified?
  end

  def edit_reason_specified?
    @fields[:edit_reason].present? && @fields[:edit_reason] != @post.edit_reason
  end

  def flagged?
    @post.is_flagged?
  end

  def edited_by_another_user?
    @post.last_editor_id != @editor.id
  end

  def original_raw_key
    "original_raw_#{(@last_version_at.to_f * 1000).to_i}#{@post.id}"
  end

  def original_cooked_key
    "original_cooked_#{(@last_version_at.to_f * 1000).to_i}#{@post.id}"
  end

  def cached_original_raw
    @cached_original_raw ||= Discourse.redis.get(original_raw_key)
  end

  def cached_original_cooked
    @cached_original_cooked ||= Discourse.redis.get(original_cooked_key)
  end

  def original_raw
    cached_original_raw || @post.raw
  end

  def original_raw=(val)
    @cached_original_raw = val
    Discourse.redis.setex(original_raw_key, SiteSetting.editing_grace_period + 1, val)
  end

  def original_cooked=(val)
    @cached_original_cooked = val
    Discourse.redis.setex(original_cooked_key, SiteSetting.editing_grace_period + 1, val)
  end

  def diff_size(before, after)
    @diff_size ||=
      begin
        ONPDiff.new(before, after).short_diff.sum { |str, type| type == :common ? 0 : str.size }
      end
  end

  def grace_period_edit?
    return false if (@revised_at - @last_version_at) > SiteSetting.editing_grace_period.to_i

    if new_raw = @fields[:raw]
      max_diff = SiteSetting.editing_grace_period_max_diff.to_i
      if @editor.staff? || (@editor.trust_level > 1)
        max_diff = SiteSetting.editing_grace_period_max_diff_high_trust.to_i
      end

      if (original_raw.size - new_raw.size).abs > max_diff ||
           diff_size(original_raw, new_raw) > max_diff
        return false
      end
    end

    true
  end

  def owner_changed?
    @fields.has_key?(:user_id) && @fields[:user_id] != @post.user_id
  end

  def force_new_version?
    @opts[:force_new_version] == true
  end

  def revise_and_create_new_version
    @version_changed = true
    @post.version += 1
    @post.public_version += 1
    @post.last_version_at = @revised_at

    revise
    perform_edit
    bump_topic
  end

  def revise
    update_post
    update_topic if topic_changed?
    create_or_update_revision
    remove_flags_and_unhide_post
  end

  USER_ACTIONS_TO_REMOVE = [UserAction::REPLY, UserAction::RESPONSE]

  def update_post
    if @fields.has_key?("user_id") && @fields["user_id"] != @post.user_id && @post.user_id != nil
      prev_owner = User.find(@post.user_id)
      new_owner = User.find(@fields["user_id"])

      UserAction
        .where(target_post_id: @post.id)
        .where(user_id: prev_owner.id)
        .where(action_type: USER_ACTIONS_TO_REMOVE)
        .update_all(user_id: new_owner.id)

      if @post.post_number == 1
        UserAction
          .where(target_topic_id: @post.topic_id)
          .where(user_id: prev_owner.id)
          .where(action_type: UserAction::NEW_TOPIC)
          .update_all(user_id: new_owner.id)
      end
    end

    POST_TRACKED_FIELDS.each do |field|
      @post.public_send("#{field}=", @fields[field]) if @fields.has_key?(field)
    end

    @post.edit_reason = @fields[:edit_reason] if should_create_new_version?
    @post.last_editor_id = @editor.id
    @post.word_count = @fields[:raw].scan(/[[:word:]]+/).size if @fields.has_key?(:raw)
    @post.self_edits += 1 if self_edit?

    @post.extract_quoted_post_numbers

    @post_successfully_saved = @post.save(validate: @validate_post)
    @post.link_post_uploads
    @post.save_reply_relationships

    @editor.increment_post_edits_count if @post_successfully_saved

    # post owner changed
    if prev_owner && new_owner && prev_owner != new_owner
      likes =
        UserAction
          .where(target_post_id: @post.id)
          .where(user_id: prev_owner.id)
          .where(action_type: UserAction::WAS_LIKED)
          .update_all(user_id: new_owner.id)

      private_message = @topic.private_message?

      prev_owner_user_stat = prev_owner.user_stat

      unless private_message
        UserStatCountUpdater.decrement!(@post, user_stat: prev_owner_user_stat) if !@post.trashed?
        prev_owner_user_stat.likes_received -= likes
      end

      if @post.created_at == prev_owner.user_stat.first_post_created_at
        prev_owner_user_stat.update!(
          first_post_created_at: prev_owner.posts.order("created_at ASC").first.try(:created_at),
        )
      end

      new_owner_user_stat = new_owner.user_stat
      unless private_message
        UserStatCountUpdater.increment!(@post, user_stat: new_owner_user_stat) if !@post.trashed?
        new_owner_user_stat.likes_received += likes
      end
      new_owner_user_stat.save!
    end
  end

  def self_edit?
    @editor == @post.user
  end

  def remove_flags_and_unhide_post
    return if @opts[:deleting_post]
    return unless editing_a_flagged_and_hidden_post?

    flaggers = []
    @post
      .post_actions
      .where(post_action_type_id: PostActionType.flag_types_without_additional_message.values)
      .each do |action|
        flaggers << action.user if action.user
        action.remove_act!(Discourse.system_user)
      end

    @post.unhide!
    PostActionNotifier.after_post_unhide(@post, flaggers)
  end

  def editing_a_flagged_and_hidden_post?
    self_edit? && @post.hidden &&
      @post.hidden_reason_id == Post.hidden_reasons[:flag_threshold_reached]
  end

  def update_topic
    Topic.transaction do
      PostRevisor.tracked_topic_fields.each do |f, cb|
        if !@topic_changes.errored? && @fields.has_key?(f)
          cb.call(@topic_changes, @fields[f], @fields)
        end
      end

      unless @topic_changes.errored?
        @topic_changes.check_result(@topic.save(validate: @validate_topic))
      end
    end
  end

  def create_or_update_revision
    return if @skip_revision
    # don't create an empty revision if something failed
    return unless successfully_saved_post_and_topic
    @version_changed ? create_revision : update_revision
  end

  def create_revision
    modifications = post_changes.merge(@topic_changes.diff)

    modifications["raw"][0] = cached_original_raw || modifications["raw"][0] if modifications["raw"]

    if modifications["cooked"]
      modifications["cooked"][0] = cached_original_cooked || modifications["cooked"][0]
    end

    @post_revision =
      PostRevision.create!(
        user_id: @post.last_editor_id,
        post_id: @post.id,
        number: @post.version,
        modifications: modifications,
        hidden: only_hidden_tags_changed?,
      )
  end

  def update_revision
    return unless revision = PostRevision.find_by(post_id: @post.id, number: @post.version)
    revision.user_id = @post.last_editor_id
    modifications = post_changes.merge(@topic_changes.diff)

    modifications.each_key do |field|
      if revision.modifications.has_key?(field)
        old_value = revision.modifications[field][0]
        new_value = modifications[field][1]
        if old_value.to_s != new_value.to_s
          revision.modifications[field] = [old_value, new_value]
        else
          revision.modifications.delete(field)
        end
      else
        revision.modifications[field] = modifications[field]
      end
    end
    # should probably do this before saving the post!
    if revision.modifications.empty?
      revision.destroy
      @post.last_editor_id =
        PostRevision.where(post_id: @post.id).order(number: :desc).pick(:user_id) || @post.user_id
      @post.version -= 1
      @post.public_version -= 1
      @post.save(validate: @validate_post)
    else
      revision.save
    end
  end

  def post_changes
    @post.previous_changes.slice(*POST_TRACKED_FIELDS)
  end

  def topic_diff
    @topic_changes.diff
  end

  def perform_edit
    return if bypass_rate_limiter?
    EditRateLimiter.new(@editor).performed!
  end

  def bypass_rate_limiter?
    @opts[:bypass_rate_limiter] == true
  end

  def bump_topic
    return if bypass_bump? || !is_last_post?
    @topic.update_column(:bumped_at, Time.now)
    TopicTrackingState.publish_muted(@topic)
    TopicTrackingState.publish_unmuted(@topic)
    TopicTrackingState.publish_latest(@topic)
  end

  def bypass_bump?
    !@post_successfully_saved || @topic_changes.errored? || @opts[:bypass_bump] == true ||
      @post.whisper? || only_hidden_tags_changed?
  end

  def only_hidden_tags_changed?
    return false if (hidden_tag_names = DiscourseTagging.hidden_tag_names).blank?

    modifications = post_changes.merge(@topic_changes.diff)
    if modifications.keys.size == 1 && (tags_diff = modifications["tags"]).present?
      a, b = tags_diff[0] || [], tags_diff[1] || []
      changed_tags = ((a + b) - (a & b)).map(&:presence).compact
      return true if (changed_tags - hidden_tag_names).empty?
    end

    false
  end

  def is_last_post?
    !Post.where(topic_id: @topic.id).where("post_number > ?", @post.post_number).exists?
  end

  def plugin_callbacks
    DiscourseEvent.trigger(:before_edit_post, @post, @fields)
    DiscourseEvent.trigger(:validate_post, @post)
  end

  def revise_topic
    return unless @post.is_first_post?

    update_topic_excerpt
    update_category_description
  end

  def update_topic_excerpt
    @topic.update_excerpt(@post.excerpt_for_topic)
  end

  def update_category_description
    return unless category = Category.find_by(topic_id: @topic.id)

    doc = Nokogiri::HTML5.fragment(@post.cooked)
    doc.css("img").remove

    if html = doc.css("p").first&.inner_html&.strip
      new_description = html unless html.starts_with?(Category.post_template[0..50])
      category.update_column(:description, new_description)
      @category_changed = category
    else
      @post.errors.add(:base, I18n.t("category.errors.description_incomplete"))
    end
  end

  def advance_draft_sequence
    @post.advance_draft_sequence
  end

  def post_process_post
    @post.invalidate_oneboxes = true
    @post.trigger_post_process
    DiscourseEvent.trigger(:post_edited, @post, self.topic_changed?, self)
  end

  def alert_users
    return if @editor.id == Discourse::SYSTEM_USER_ID
    Jobs.enqueue(:post_alert, post_id: @post.id)
  end

  def publish_changes
    options =
      if !@topic_changes.diff.empty? && !@topic_changes.errored?
        { reload_topic: true }
      else
        {}
      end

    DiscourseEvent.trigger(:before_post_publish_changes, post_changes, @topic_changes, options)

    @post.publish_change_to_clients!(:revised, options)
  end

  def grant_badge
    BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: @post)
  end

  def successfully_saved_post_and_topic
    @post_successfully_saved && !@topic_changes.errored?
  end

  def guardian
    @guardian ||= Guardian.new(@editor)
  end

  def raw_changed?
    @fields.has_key?(:raw) && @fields[:raw] != cached_original_raw && @post_successfully_saved
  end

  def topic_title_changed?
    topic_changed? && @fields.has_key?(:title) && topic_diff.has_key?(:title) &&
      !@topic_changes.errored?
  end

  def reviewable_content_changed?
    raw_changed? || topic_title_changed?
  end
end
