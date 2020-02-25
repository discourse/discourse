# frozen_string_literal: true

class PostAction < ActiveRecord::Base
  include RateLimiter::OnCreateRecord
  include Trashable

  belongs_to :post
  belongs_to :user
  belongs_to :post_action_type
  belongs_to :related_post, class_name: 'Post'
  belongs_to :target_user, class_name: 'User'

  rate_limit :post_action_rate_limiter

  scope :spam_flags, -> { where(post_action_type_id: PostActionType.types[:spam]) }
  scope :flags, -> { where(post_action_type_id: PostActionType.notify_flag_type_ids) }
  scope :publics, -> { where(post_action_type_id: PostActionType.public_type_ids) }
  scope :active, -> { where(disagreed_at: nil, deferred_at: nil, agreed_at: nil, deleted_at: nil) }

  after_save :update_counters
  validate :ensure_unique_actions, on: :create

  def self.counts_for(collection, user)
    return {} if collection.blank? || !user

    collection_ids = collection.map(&:id)
    user_id = user.try(:id) || 0

    post_actions = PostAction.where(post_id: collection_ids, user_id: user_id)

    user_actions = {}
    post_actions.each do |post_action|
      user_actions[post_action.post_id] ||= {}
      user_actions[post_action.post_id][post_action.post_action_type_id] = post_action
    end

    user_actions
  end

  def self.lookup_for(user, topics, post_action_type_id)
    return if topics.blank?
    # in critical path 2x faster than AR
    #
    topic_ids = topics.map(&:id)
    map = {}

    builder = DB.build <<~SQL
      SELECT p.topic_id, p.post_number
      FROM post_actions pa
      JOIN posts p ON pa.post_id = p.id
      WHERE p.deleted_at IS NULL AND pa.deleted_at IS NULL AND
         pa.post_action_type_id = :post_action_type_id AND
         pa.user_id = :user_id AND
         p.topic_id IN (:topic_ids)
      ORDER BY p.topic_id, p.post_number
    SQL

    builder.query(user_id: user.id, post_action_type_id: post_action_type_id, topic_ids: topic_ids).each do |row|
      (map[row.topic_id] ||= []) << row.post_number
    end

    map
  end

  def self.count_per_day_for_type(post_action_type, opts = nil)
    opts ||= {}
    result = unscoped.where(post_action_type_id: post_action_type)
    result = result.where('post_actions.created_at >= ?', opts[:start_date] || (opts[:since_days_ago] || 30).days.ago)
    result = result.where('post_actions.created_at <= ?', opts[:end_date]) if opts[:end_date]
    result = result.joins(post: :topic).merge(Topic.in_category_and_subcategories(opts[:category_id])) if opts[:category_id]
    result.group('date(post_actions.created_at)')
      .order('date(post_actions.created_at)')
      .count
  end

  def add_moderator_post_if_needed(moderator, disposition, delete_post = false)
    return if !SiteSetting.auto_respond_to_flag_actions
    return if related_post.nil? || related_post.topic.nil?
    return if staff_already_replied?(related_post.topic)
    message_key = +"flags_dispositions.#{disposition}"
    message_key << "_and_deleted" if delete_post

    I18n.with_locale(SiteSetting.default_locale) do
      related_post.topic.add_moderator_post(moderator, I18n.t(message_key))
    end
  end

  def staff_already_replied?(topic)
    topic.posts.where("user_id IN (SELECT id FROM users WHERE moderator OR admin) OR (post_type != :regular_post_type)", regular_post_type: Post.types[:regular]).exists?
  end

  def self.limit_action!(user, post, post_action_type_id)
    RateLimiter.new(user, "post_action-#{post.id}_#{post_action_type_id}", 4, 1.minute).performed!
  end

  def self.act(created_by, post, post_action_type_id, opts = {})
    Discourse.deprecate("PostAction.act is deprecated. Use `PostActionCreator` instead.", output_in_test: true)

    result = PostActionCreator.new(
      created_by,
      post,
      post_action_type_id,
      message: opts[:message]
    ).perform

    result.success? ? result.post_action : nil
  end

  def self.copy(original_post, target_post)
    cols_to_copy = (column_names - %w{id post_id}).join(', ')

    DB.exec <<~SQL
    INSERT INTO post_actions(post_id, #{cols_to_copy})
    SELECT #{target_post.id}, #{cols_to_copy}
    FROM post_actions
    WHERE post_id = #{original_post.id}
    SQL

    target_post.post_actions.each { |post_action| post_action.update_counters }
  end

  def self.remove_act(user, post, post_action_type_id)
    Discourse.deprecate(
      "PostAction.remove_act is deprecated. Use `PostActionDestroyer` instead.",
      output_in_test: true
    )

    PostActionDestroyer.new(user, post, post_action_type_id).perform
  end

  def remove_act!(user)
    trash!(user)
    # NOTE: save is called to ensure all callbacks are called
    # trash will not trigger callbacks, and triggering after_commit
    # is not trivial
    save
  end

  def is_bookmark?
    post_action_type_id == PostActionType.types[:bookmark]
  end

  def is_like?
    post_action_type_id == PostActionType.types[:like]
  end

  def is_flag?
    !!PostActionType.notify_flag_types[post_action_type_id]
  end

  def is_private_message?
    post_action_type_id == PostActionType.types[:notify_user] ||
    post_action_type_id == PostActionType.types[:notify_moderators]
  end

  # A custom rate limiter for this model
  def post_action_rate_limiter
    return unless is_flag? || is_bookmark? || is_like?

    return @rate_limiter if @rate_limiter.present?

    %w(like flag bookmark).each do |type|
      if public_send("is_#{type}?")
        limit = SiteSetting.get("max_#{type}s_per_day")

        if is_like? && user && user.trust_level >= 2
          multiplier = SiteSetting.get("tl#{user.trust_level}_additional_likes_per_day_multiplier").to_f
          multiplier = 1.0 if multiplier < 1.0

          limit = (limit * multiplier).to_i
        end

        @rate_limiter = RateLimiter.new(user, "create_#{type}", limit, 1.day.to_i)
        return @rate_limiter
      end
    end
  end

  def ensure_unique_actions
    post_action_type_ids = is_flag? ? PostActionType.notify_flag_types.values : post_action_type_id

    acted = PostAction.where(user_id: user_id)
      .where(post_id: post_id)
      .where(post_action_type_id: post_action_type_ids)
      .where(deleted_at: nil)
      .where(disagreed_at: nil)
      .where(targets_topic: targets_topic)
      .exists?

    errors.add(:post_action_type_id) if acted
  end

  def post_action_type_key
    PostActionType.types[post_action_type_id]
  end

  def update_counters
    # Update denormalized counts
    column = "#{post_action_type_key}_count"
    count = PostAction.where(post_id: post_id)
      .where(post_action_type_id: post_action_type_id)
      .count

    # We probably want to refactor this method to something cleaner.
    case post_action_type_key
    when :like
      # 'like_score' is weighted higher for staff accounts
      score = PostAction.joins(:user)
        .where(post_id: post_id)
        .sum("CASE WHEN users.moderator OR users.admin THEN #{SiteSetting.staff_like_weight} ELSE 1 END")
      Post.where(id: post_id).update_all ["like_count = :count, like_score = :score", count: count, score: score]
    else
      if ActiveRecord::Base.connection.column_exists?(:posts, column)
        Post.where(id: post_id).update_all ["#{column} = ?", count]
      end
    end

    topic_id = Post.with_deleted.where(id: post_id).pluck_first(:topic_id)

    # topic_user
    if [:like, :bookmark].include? post_action_type_key
      TopicUser.update_post_action_cache(user_id: user_id,
                                         topic_id: topic_id,
                                         post_action_type: post_action_type_key)
    end

    if column == "like_count"
      topic_count = Post.where(topic_id: topic_id).sum(column)
      Topic.where(id: topic_id).update_all ["#{column} = ?", topic_count]
    end

  end
end

# == Schema Information
#
# Table name: post_actions
#
#  id                  :integer          not null, primary key
#  post_id             :integer          not null
#  user_id             :integer          not null
#  post_action_type_id :integer          not null
#  deleted_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  deleted_by_id       :integer
#  related_post_id     :integer
#  staff_took_action   :boolean          default(FALSE), not null
#  deferred_by_id      :integer
#  targets_topic       :boolean          default(FALSE), not null
#  agreed_at           :datetime
#  agreed_by_id        :integer
#  deferred_at         :datetime
#  disagreed_at        :datetime
#  disagreed_by_id     :integer
#
# Indexes
#
#  idx_unique_actions                                          (user_id,post_action_type_id,post_id,targets_topic) UNIQUE WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL))
#  idx_unique_flags                                            (user_id,post_id,targets_topic) UNIQUE WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL) AND (post_action_type_id = ANY (ARRAY[3, 4, 7, 8])))
#  index_post_actions_on_post_action_type_id_and_disagreed_at  (post_action_type_id,disagreed_at) WHERE (disagreed_at IS NULL)
#  index_post_actions_on_post_id                               (post_id)
#  index_post_actions_on_user_id                               (user_id)
#  index_post_actions_on_user_id_and_post_action_type_id       (user_id,post_action_type_id) WHERE (deleted_at IS NULL)
#
