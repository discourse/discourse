# frozen_string_literal: true

# name: discourse-post-voting
# about: Allows the creation of topics with votable posts.
# meta_topic_id: 227808
# version: 0.0.1
# authors: Alan Tan
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-post-voting

register_asset "stylesheets/common/post-voting.scss"
register_asset "stylesheets/common/post-voting-crawler.scss"

enabled_site_setting :post_voting_enabled

require_relative "lib/post_voting/category_mode_site_setting"

module ::PostVoting
  PLUGIN_NAME = "discourse-post-voting"
  ALLOW_POST_VOTING = "allow_post_voting"
  APPLY_TO_SUBCATEGORIES = "apply_post_voting_to_subcategories"

  def self.overrides_cache
    @overrides_cache ||= ::DistributedCache.new("post_voting_category_overrides")
  end

  def self.post_voting_enabled_for?(category_id)
    return true if SiteSetting.post_voting_category_mode == CategoryModeSiteSetting::ALL_CATEGORIES
    return false if category_id.blank?

    override = category_override(category_id)
    override.nil? ? mode_default : override
  end

  def self.mode_default
    SiteSetting.post_voting_category_mode == CategoryModeSiteSetting::OPT_OUT
  end

  def self.category_override(category_id)
    return nil if category_id.blank?

    category_overrides[category_id.to_i]
  end

  def self.stored_category_override(category_id)
    CategoryModeSiteSetting.normalize_override(
      ::CategoryCustomField.where(category_id: category_id, name: ALLOW_POST_VOTING).pick(:value),
    )
  end

  def self.category_overrides
    cache = overrides_cache
    cached = cache["overrides"]
    return cached if cached

    generation = cache["generation"]
    resolved = resolve_category_overrides

    if cache["generation"] == generation
      cache["overrides"] = resolved
      cache.delete("overrides") if cache["generation"] != generation
    end

    resolved
  end

  def self.clear_category_overrides_cache(after_commit: true)
    clear = -> do
      overrides_cache.clear(after_commit: false)
      overrides_cache["generation"] = SecureRandom.hex(8)
    end

    if after_commit && !GlobalSetting.skip_db?
      ::DB.after_commit { clear.call }
    else
      clear.call
    end
  end

  def self.resolve_category_overrides
    ::CategoryCustomField
      .where(name: ALLOW_POST_VOTING)
      .pluck(:category_id, :value)
      .each_with_object({}) do |(category_id, value), overrides|
        override = CategoryModeSiteSetting.normalize_override(value)
        overrides[category_id] = override if !override.nil?
      end
  end

  # Selecting a mode sets every category to that mode's default, so the category
  # setting always shows the value in force rather than a blank that means
  # something different in each mode.
  def self.reset_category_overrides!
    return if SiteSetting.post_voting_category_mode == CategoryModeSiteSetting::ALL_CATEGORIES

    write_category_overrides(::Category.pluck(:id), mode_default)
    invalidate_category_caches
  end

  def self.backfill_missing_category_overrides!
    return if SiteSetting.post_voting_category_mode == CategoryModeSiteSetting::ALL_CATEGORIES

    missing_ids = ::Category.pluck(:id) - resolve_category_overrides.keys
    return if missing_ids.blank?

    write_category_overrides(missing_ids, mode_default)
    invalidate_category_caches
  end

  def self.write_category_override(category, value)
    category.upsert_custom_fields(ALLOW_POST_VOTING => value)
  end

  def self.write_category_overrides(category_ids, value)
    return if category_ids.blank?

    stored = value ? "t" : "f"
    now = Time.zone.now
    scope = ::CategoryCustomField.where(name: ALLOW_POST_VOTING, category_id: category_ids)
    existing_ids = scope.pluck(:category_id)

    scope.update_all(value: stored, updated_at: now) if existing_ids.present?

    missing_ids = category_ids - existing_ids
    return if missing_ids.blank?

    ::CategoryCustomField.insert_all(
      missing_ids.map do |category_id|
        {
          category_id: category_id,
          name: ALLOW_POST_VOTING,
          value: stored,
          created_at: now,
          updated_at: now,
        }
      end,
    )
  end

  def self.invalidate_category_caches
    clear_category_overrides_cache(after_commit: false)
    clear_category_overrides_cache
    ::Site.clear_cache
  end

  def self.apply_to_subcategories!(category_id)
    clear_category_overrides_cache(after_commit: false)
    value = post_voting_enabled_for?(category_id)
    descendant_ids = ::Category.subcategory_ids(category_id) - [category_id]

    write_category_overrides(descendant_ids, value)
    invalidate_category_caches
  end

  def self.discard_apply_to_subcategories_flag(category_id)
    ::CategoryCustomField.where(category_id: category_id, name: APPLY_TO_SUBCATEGORIES).delete_all
  end
end

require_relative "lib/post_voting/engine"

after_initialize do
  Discourse::Application.routes.append { mount PostVoting::Engine, at: "post_voting" }

  require_relative "lib/post_voting/vote_manager"
  require_relative "lib/post_voting/guardian_extension"
  require_relative "lib/post_voting/comment_creator"
  require_relative "lib/post_voting/comment_review_queue"
  require_relative "extensions/category_extension"
  require_relative "extensions/post_extension"
  require_relative "extensions/post_serializer_extension"
  require_relative "extensions/topic_extension"
  require_relative "extensions/topic_list_item_serializer_extension"
  require_relative "extensions/topic_view_serializer_extension"
  require_relative "extensions/topic_view_extension"
  require_relative "extensions/user_extension"
  require_relative "app/validators/post_voting_comment_validator"
  require_relative "app/controllers/post_voting/votes_controller"
  require_relative "app/controllers/post_voting/comments_controller"
  require_relative "app/models/post_voting_vote"
  require_relative "app/models/post_voting_comment"
  require_relative "app/models/post_voting_comment_custom_field"
  require_relative "app/models/reviewable_post_voting_comment"
  require_relative "app/serializers/basic_voter_serializer"
  require_relative "app/serializers/post_voting_comment_serializer"
  require_relative "app/serializers/reviewable_post_voting_comment_serializer"

  register_svg_icon "vote-up"
  register_svg_icon "vote-up-filled"
  register_svg_icon "info"

  register_post_custom_field_type("vote_history", :json)
  register_post_custom_field_type("vote_count", :integer)

  register_reviewable_type ReviewablePostVotingComment

  if Rails.env.local? && enabled?
    require_relative "lib/discourse_dev/reviewable_post_voting_comment"
    DiscoursePluginRegistry.discourse_dev_populate_reviewable_types.add DiscourseDev::ReviewablePostVotingComment
  end

  reloadable_patch do
    Category.prepend(PostVoting::CategoryExtension)
    Post.include(PostVoting::PostExtension)
    Topic.include(PostVoting::TopicExtension)
    PostSerializer.include(PostVoting::PostSerializerExtension)
    TopicView.prepend(PostVoting::TopicViewExtension)
    TopicViewSerializer.include(PostVoting::TopicViewSerializerExtension)
    TopicListItemSerializer.include(PostVoting::TopicListItemSerializerExtension)
    User.include(PostVoting::UserExtension)
    Guardian.prepend(PostVoting::GuardianExtension)
  end

  # TODO: Performance of the query degrades as the number of posts a user has voted
  # on increases. We should probably keep a counter cache in the user's
  # custom fields.
  add_to_class(:user, :vote_count) { Post.where(user_id: id).sum(:qa_vote_count) }

  add_to_serializer(:user_card, :vote_count) { object.vote_count }

  add_to_class(:topic_view, :user_voted_posts) do |user|
    @user_voted_posts ||= {}

    @user_voted_posts[user.id] ||= PostVotingVote
      .where(user: user, post: @posts)
      .distinct
      .pluck(:post_id)
  end

  add_to_class(:topic_view, :user_voted_posts_last_timestamp) do |user|
    @user_voted_posts_last_timestamp ||= {}

    @user_voted_posts_last_timestamp[user.id] ||= PostVotingVote
      .where(user: user, post: @posts)
      .group(:votable_id, :created_at)
      .pluck(:votable_id, :created_at)
  end

  TopicView.apply_custom_default_scope do |scope, topic_view|
    if topic_view.topic.is_post_voting? &&
         !topic_view.instance_variable_get(:@replies_to_post_number) &&
         !topic_view.instance_variable_get(:@post_ids)
      scope = scope.where(reply_to_post_number: nil)

      if topic_view.instance_variable_get(:@filter) != TopicView::ACTIVITY_FILTER
        scope =
          scope
            .where.not(post_type: [Post.types[:whisper], Post.types[:small_action]])
            .unscope(:order)
            .order("CASE post_number WHEN 1 THEN 0 ELSE 1 END, qa_vote_count DESC, post_number ASC")
      end

      scope
    else
      scope
    end
  end

  register_html_builder("server:topic-show-crawler-post-end") do |controller, post:|
    topic_view = controller.instance_variable_get(:@topic_view)
    next if !topic_view&.topic&.is_post_voting?

    comments = topic_view.comments[post.id]
    reply_count = post.is_first_post? ? topic_view.filtered_posts.count - 1 : 0
    next if comments.blank? && reply_count <= 0

    ApplicationController.render(
      template: "post_voting/crawler_post",
      layout: false,
      assigns: {
        comments: comments,
        reply_count: reply_count,
      },
    )
  end

  TopicView.on_preload do |topic_view|
    next if !topic_view.topic.is_post_voting?

    topic_view.comments = {}
    topic_view.comments_counts = {}
    topic_view.posts_user_voted = {}
    topic_view.comments_user_voted = {}
    topic_view.posts_voted_on = []

    post_ids = topic_view.posts.pluck(:id)
    next if post_ids.blank?

    post_ids_sql = post_ids.join(",")

    comment_ids_sql = <<~SQL
    SELECT
      post_voting_comments.id
    FROM post_voting_comments
    INNER JOIN LATERAL (
      SELECT 1
      FROM (
        SELECT
          comments.id
        FROM post_voting_comments comments
        WHERE comments.post_id = post_voting_comments.post_id
        AND comments.deleted_at IS NULL
        ORDER BY comments.id ASC
        LIMIT #{TopicView::PRELOAD_COMMENTS_COUNT}
      ) X
      WHERE X.id = post_voting_comments.id
    ) Y ON true
    WHERE post_voting_comments.post_id IN (#{post_ids_sql})
    AND post_voting_comments.deleted_at IS NULL
    SQL

    PostVotingComment
      .includes(:user)
      .where("id IN (#{comment_ids_sql})")
      .order(id: :asc)
      .each do |comment|
        topic_view.comments[comment.post_id] ||= []
        topic_view.comments[comment.post_id] << comment
      end

    topic_view.comments_counts = PostVotingComment.where(post_id: post_ids).group(:post_id).count

    if topic_view.guardian.user
      PostVotingVote
        .where(user: topic_view.guardian.user, votable_type: "Post", votable_id: post_ids)
        .pluck(:votable_id, :direction)
        .each { |post_id, direction| topic_view.posts_user_voted[post_id] = direction }

      PostVotingVote
        .joins(
          "INNER JOIN post_voting_comments comments ON comments.id = post_voting_votes.votable_id",
        )
        .where(user: topic_view.guardian.user, votable_type: "PostVotingComment")
        .where("comments.post_id IN (?)", post_ids)
        .pluck(:votable_id)
        .each { |votable_id| topic_view.comments_user_voted[votable_id] = true }
    end

    topic_view.posts_voted_on =
      PostVotingVote.where(votable_type: "Post", votable_id: post_ids).distinct.pluck(:votable_id)
  end

  add_permitted_post_create_param(:create_as_post_voting)

  # TODO: Core should be exposing the following as proper plugin interfaces.
  NewPostManager.add_plugin_payload_attribute(:subtype)
  TopicSubtype.register(Topic::POST_VOTING_SUBTYPE)

  NewPostManager.add_handler do |manager|
    if !manager.args[:topic_id] && manager.args[:create_as_post_voting].to_s == "true" &&
         (manager.args[:archetype].blank? || manager.args[:archetype] == Archetype.default)
      manager.args[:subtype] = Topic::POST_VOTING_SUBTYPE
    end

    false
  end

  register_modifier(:topic_embed_import_create_args) do |args|
    category_id = args[:category]
    next args unless category_id
    next args if args[:archetype] != Archetype.default && args[:archetype].present?

    category = Category.find_by(id: category_id)

    if PostVoting.post_voting_enabled_for?(category_id) &&
         (category&.create_as_post_voting_default || category&.only_post_voting_in_this_category)
      args[:subtype] = Topic::POST_VOTING_SUBTYPE
    end

    args
  end

  register_category_custom_field_type(PostVoting::CREATE_AS_POST_VOTING_DEFAULT, :boolean)
  register_preloaded_category_custom_fields(PostVoting::CREATE_AS_POST_VOTING_DEFAULT)

  add_to_class(:category, :create_as_post_voting_default) do
    ActiveModel::Type::Boolean.new.cast(custom_fields[PostVoting::CREATE_AS_POST_VOTING_DEFAULT])
  end
  add_to_serializer(:basic_category, :create_as_post_voting_default) do
    object.create_as_post_voting_default
  end

  add_to_serializer(:current_user, :can_flag_post_voting_comments) do
    scope.can_flag_post_voting_comments?
  end

  register_category_custom_field_type(PostVoting::ONLY_POST_VOTING_IN_THIS_CATEGORY, :boolean)
  register_preloaded_category_custom_fields PostVoting::ONLY_POST_VOTING_IN_THIS_CATEGORY
  register_preloaded_category_custom_fields PostVoting::CREATE_AS_POST_VOTING_DEFAULT

  add_to_class(:category, :only_post_voting_in_this_category) do
    ActiveModel::Type::Boolean.new.cast(
      custom_fields[PostVoting::ONLY_POST_VOTING_IN_THIS_CATEGORY],
    )
  end
  add_to_serializer(:basic_category, :only_post_voting_in_this_category) do
    object.only_post_voting_in_this_category
  end

  register_category_custom_field_type(PostVoting::ALLOW_POST_VOTING, :boolean)
  register_preloaded_category_custom_fields PostVoting::ALLOW_POST_VOTING
  register_category_custom_field_type(PostVoting::APPLY_TO_SUBCATEGORIES, :boolean)

  add_to_serializer(:basic_category, :post_voting_allowed) do
    PostVoting.post_voting_enabled_for?(object.id)
  end

  %i[category_created category_updated category_destroyed].each do |event|
    on(event) { PostVoting.clear_category_overrides_cache }
  end

  add_model_callback(CategoryCustomField, :after_commit) do
    PostVoting.clear_category_overrides_cache if name == PostVoting::ALLOW_POST_VOTING
  end

  # A new category starts from its parent's value so a subcategory added later
  # matches the tree it was created in, rather than the mode's default.
  on(:category_created) do |category|
    if SiteSetting.post_voting_category_mode == PostVoting::CategoryModeSiteSetting::ALL_CATEGORIES
      next
    end

    # A value can be submitted with the category itself, and this event fires
    # after that has committed. Inheriting unconditionally would overwrite it.
    next if !PostVoting.stored_category_override(category.id).nil?

    inherited =
      if category.parent_category_id
        PostVoting.post_voting_enabled_for?(category.parent_category_id)
      else
        PostVoting.mode_default
      end

    PostVoting.write_category_override(category, inherited)
  end

  DiscourseEvent.on(:site_setting_changed) do |name, _old_value, _new_value| # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
    PostVoting.reset_category_overrides! if name == :post_voting_category_mode
  end

  on_enabled_change do |_old_value, new_value|
    PostVoting.backfill_missing_category_overrides! if new_value
  end

  add_model_callback(:post, :before_create) do
    if SiteSetting.post_voting_enabled && is_post_voting_topic? && via_email &&
         reply_to_post_number == 1
      self.reply_to_post_number = nil
    end
  end

  register_user_destroyer_on_content_deletion_callback(
    Proc.new do |user|
      post_voting_comment_ids = PostVotingComment.where(user_id: user.id).pluck(:id)
      PostVotingComment.where(id: post_voting_comment_ids).delete_all
      ReviewablePostVotingComment.where(
        target_id: post_voting_comment_ids,
        target_type: "PostVotingComment",
      ).delete_all
      PostVoting::VoteManager.bulk_remove_votes_by(user)
    end,
  )

  register_anonymous_action("vote_post") do |user, params|
    direction = params["direction"].to_s
    next if direction != "up" && direction != "down"

    post = Post.find_by(id: params["post_id"])
    next if !user.guardian.can_vote_on_post?(post, direction: direction)

    PostVoting::VoteManager.vote(post, user, direction:)
  end
end
