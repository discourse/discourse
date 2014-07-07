require 'edit_rate_limiter'

class PostRevisor

  attr_reader :category_changed

  def initialize(post)
    @post = post
  end

  # Recognized options:
  #  :edit_reason User-supplied edit reason
  #  :new_user New owner of the post
  #  :revised_at changes the date of the revision
  #  :force_new_version bypass ninja-edit window
  #  :bypass_bump do not bump the topic, even if last post
  #  :skip_validation ask ActiveRecord to skip validations
  #
  def revise!(editor, new_raw, opts = {})
    @editor, @new_raw, @opts = editor, new_raw, opts
    return false unless should_revise?
    @post.acting_user = @editor
    revise_post
    update_category_description
    update_topic_excerpt
    post_process_post
    update_topic_word_counts
    @post.advance_draft_sequence
    PostAlerter.new.after_save_post(@post)
    publish_revision

    true
  end

  private

  def publish_revision
    MessageBus.publish("/topic/#{@post.topic_id}",{
                    id: @post.id,
                    post_number: @post.post_number,
                    updated_at: @post.updated_at,
                    type: "revised"
                  },
                  group_ids: @post.topic.secure_group_ids
    )
  end

  def should_revise?
    @post.raw != @new_raw || @opts[:changed_owner]
  end

  def revise_post
    if should_create_new_version?
      revise_and_create_new_version
    else
      update_post
    end
  end

  def get_revised_at
    @opts[:revised_at] || Time.now
  end

  def should_create_new_version?
    @post.last_editor_id != @editor.id ||
    get_revised_at - @post.last_version_at > SiteSetting.ninja_edit_window.to_i ||
    @opts[:changed_owner] == true ||
    @opts[:force_new_version] == true
  end

  def revise_and_create_new_version
    Post.transaction do
      @post.version += 1
      @post.last_version_at = get_revised_at
      update_post
      EditRateLimiter.new(@editor).performed! unless @opts[:bypass_rate_limiter] == true
      bump_topic unless @opts[:bypass_bump]
    end
  end

  def bump_topic
    unless Post.where('post_number > ? and topic_id = ?', @post.post_number, @post.topic_id).exists?
      @post.topic.update_column(:bumped_at, Time.now)
    end
  end

  def update_topic_word_counts
    Topic.exec_sql("UPDATE topics SET word_count = (SELECT SUM(COALESCE(posts.word_count, 0))
                                                    FROM posts WHERE posts.topic_id = :topic_id)
                    WHERE topics.id = :topic_id", topic_id: @post.topic_id)
  end

  def update_post
    @post.raw = @new_raw
    @post.word_count = @new_raw.scan(/\w+/).size
    @post.last_editor_id = @editor.id
    @post.edit_reason = @opts[:edit_reason] if @opts[:edit_reason]
    @post.user_id = @opts[:new_user].id if @opts[:new_user]
    @post.self_edits += 1 if @editor == @post.user

    if @editor == @post.user && @post.hidden && @post.hidden_reason_id == Post.hidden_reasons[:flag_threshold_reached]
      @post.hidden = false
      @post.hidden_reason_id = nil
      @post.hidden_at = nil
      @post.topic.update_attributes(visible: true)

      PostAction.clear_flags!(@post, -1)
    end

    @post.extract_quoted_post_numbers
    @post.save(validate: !@opts[:skip_validations])

    @post.save_reply_relationships
  end

  def update_category_description
    # If we're revising the first post, we might have to update the category description
    return unless @post.post_number == 1

    # Is there a category with our topic id?
    category = Category.find_by(topic_id: @post.topic_id)
    return unless category.present?

    # If found, update its description
    body = @post.cooked
    matches = body.scan(/\<p\>(.*)\<\/p\>/)
    if matches && matches[0] && matches[0][0]
      new_description = matches[0][0]
      new_description = nil if new_description == I18n.t("category.replace_paragraph")
      category.update_column(:description, new_description)
      @category_changed = category
    end
  end

  def update_topic_excerpt
    @post.topic.update_column(:excerpt, @post.excerpt(220, strip_links: true)) if @post.post_number == 1
  end

  def post_process_post
    @post.invalidate_oneboxes = true
    @post.trigger_post_process
  end
end
