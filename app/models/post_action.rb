require_dependency 'rate_limiter'
require_dependency 'system_message'
require 'post_action_subclass_mixin'

class PostAction < ActiveRecord::Base
  class AlreadyActed < StandardError; end

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
  after_commit :notify_subscribers

  include ActiveRecord::Inheritance

  self.inheritance_column = :post_action_type_id

  def self.store_full_sti_class
    false
  end

  def self.compute_type_int(type_id)
    if type_id == PostActionType.bookmark
      Bookmark
    elsif type_id == PostActionType.like
      Like
    elsif PostActionType.all_flag_type_ids.include? type_id
      Flag
    elsif type_id == PostActionType.types[:vote]
      PostAction
    elsif type_id == nil
      PostAction
    else
      # binding.pry
      # puts "Unknown PostActionType - #{type_id} #{type_id.class}"
      raise "Unknown PostActionType - #{type_id} #{type_id.class}"
    end
  end

  def self.compute_type(type_id)
    # Ignore non-PostAction calls
    if type_id =~ /^\d+$/
      compute_type_int type_id.to_i
    else
      super
    end
  end

  def self.subclass_from_attributes?(attrs)
    self == PostAction && super && subclass_from_attributes(attrs) != PostAction
  end

  def self.subclass_from_attributes(attrs)
    compute_type_int(attrs[:post_action_type_id].to_i)
  end

  class << self
    [
      :flag_count_by_date, :update_flagged_posts_count, :flagged_posts_count,
      :active_flags_counts_for, :agree_flags!, :clear_flags!, :defer_flags!,
      :create_message_for_post_action, :flag_counts_for, :auto_close_if_threshold_reached,
      :auto_hide_if_needed, :hide_post!, :guess_hide_reason, :target_moderators
    ].each do |sym|
      delegate sym, to: Flag
    end
  end

  def disposed_by_id
    disagreed_by_id || agreed_by_id || deferred_by_id
  end

  def disposed_at
    disagreed_at || agreed_at || deferred_at
  end

  def disposition
    return :disagreed if disagreed_at
    return :agreed if agreed_at
    return :deferred if deferred_at
    nil
  end

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
        builder = SqlBuilder.new <<SQL
        SELECT p.topic_id, p.post_number
        FROM post_actions pa
        JOIN posts p ON pa.post_id = p.id
        WHERE p.deleted_at IS NULL AND pa.deleted_at IS NULL AND
           pa.post_action_type_id = :post_action_type_id AND
           pa.user_id = :user_id AND
           p.topic_id IN (:topic_ids)
        ORDER BY p.topic_id, p.post_number
SQL

    builder.map_exec(OpenStruct, user_id: user.id, post_action_type_id: post_action_type_id, topic_ids: topic_ids).each do |row|
      (map[row.topic_id] ||= []) << row.post_number
    end


    map
  end

  def self.count_per_day_for_type(post_action_type, opts=nil)
    opts ||= {}
    result = unscoped.where(post_action_type_id: post_action_type)
    result = result.where('post_actions.created_at >= ?', opts[:start_date] || (opts[:since_days_ago] || 30).days.ago)
    result = result.where('post_actions.created_at <= ?', opts[:end_date]) if opts[:end_date]
    result = result.joins(post: :topic).where('topics.category_id = ?', opts[:category_id]) if opts[:category_id]
    result.group('date(post_actions.created_at)')
          .order('date(post_actions.created_at)')
          .count
  end

  def self.act(user, post, post_action_type_id, opts = {})
    related_post_id = create_message_for_post_action(user, post, post_action_type_id, opts)
    staff_took_action = opts[:take_action] || false

    targets_topic = if opts[:flag_topic] && post.topic
                      post.topic.reload
                      post.topic.posts_count != 1
                    end

    where_attrs = {
      post_id: post.id,
      user_id: user.id,
      post_action_type_id: post_action_type_id
    }

    action_attrs = {}
    action_attrs = {
      staff_took_action: staff_took_action,
      related_post_id: related_post_id,
      targets_topic: !!targets_topic
    } if PostActionType.all_flag_type_ids.include? post_action_type_id

    # First try to revive a trashed record
    post_action = PostAction.where(where_attrs)
                            .with_deleted
                            .where("deleted_at IS NOT NULL")
                            .first

    if post_action
      post_action.recover!
      action_attrs.each { |attr, val| post_action.send("#{attr}=", val) }
      post_action.save
    else
      post_action = create(where_attrs.merge(action_attrs))
      if post_action && post_action.errors.count == 0
        BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: post_action)
      end
    end

    # agree with other flags
    if staff_took_action
      PostAction.agree_flags!(post, user)

      # update counters
      post_action.try(:update_counters)
    end

    post_action
  rescue ActiveRecord::RecordNotUnique
    # can happen despite being .create
    # since already bookmarked
    PostAction.where(where_attrs).first
  end

  def self.remove_act(user, post, post_action_type_id)
    finder = PostAction.where(post_id: post.id, user_id: user.id, post_action_type_id: post_action_type_id)
    finder = finder.with_deleted.includes(:post) if user.try(:staff?)
    if action = finder.first
      action.remove_act!(user)
      action.post.unhide! if action.staff_took_action
    end
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
    PostActionType.flag_types.values.include?(post_action_type_id)
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
      if send("is_#{type}?")
        limit = SiteSetting.send("max_#{type}s_per_day")

        if is_like? && user && user.trust_level >= 2
          multiplier = SiteSetting.send("tl#{user.trust_level}_additional_likes_per_day_multiplier").to_f
          multiplier = 1.0 if multiplier < 1.0

          limit = (limit * multiplier ).to_i
        end

        @rate_limiter = RateLimiter.new(user, "create_#{type}",limit, 1.day.to_i)
        return @rate_limiter
      end
    end
  end

  before_create do
    unless is_flag? || is_like? || is_bookmark?
      # Like, Flag, Bookmark do their own uniqueness checks
      raise AlreadyActed if PostAction.where(user_id: user_id)
                              .where(post_id: post_id)
                              .where(post_action_type_id: post_action_type_id)
                              .where(deleted_at: nil)
                              .where(disagreed_at: nil)
                              .where(targets_topic: targets_topic)
                              .exists?
    end
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
    when :vote
      # Voting also changes the sort_order
      Post.where(id: post_id).update_all ["vote_count = :count, sort_order = :max - :count", count: count, max: Topic.max_sort_order]
    when :like
      # 'like_score' is weighted higher for staff accounts
      score = PostAction.joins(:user)
                        .where(post_id: post_id)
                        .sum("CASE WHEN users.moderator OR users.admin THEN #{SiteSetting.staff_like_weight} ELSE 1 END")
      Post.where(id: post_id).update_all ["like_count = :count, like_score = :score", count: count, score: score]
    else
      Post.where(id: post_id).update_all ["#{column} = ?", count]
    end


    topic_id = Post.with_deleted.where(id: post_id).pluck(:topic_id).first

    # topic_user
    if [:like,:bookmark].include? post_action_type_key
      TopicUser.update_post_action_cache(user_id: user_id,
                                         topic_id: topic_id,
                                         post_action_type: post_action_type_key)
    end

    topic_count = Post.where(topic_id: topic_id).sum(column)
    Topic.where(id: topic_id).update_all ["#{column} = ?", topic_count]

    if PostActionType.notify_flag_type_ids.include?(post_action_type_id)
      PostAction.update_flagged_posts_count
    end

  end

  def notify_subscribers
    if (is_like? || is_flag?) && post
      post.publish_change_to_clients! :acted
    end
  end

  def self.post_action_type_for_post(post_id)
    post_action = PostAction.find_by(deferred_at: nil, post_id: post_id, post_action_type_id: PostActionType.flag_types.values, deleted_at: nil)
    PostActionType.types[post_action.post_action_type_id]
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
#  idx_unique_actions                                     (user_id,post_action_type_id,post_id,targets_topic) UNIQUE
#  idx_unique_flags                                       (user_id,post_id,targets_topic) UNIQUE
#  index_post_actions_on_post_id                          (post_id)
#  index_post_actions_on_user_id_and_post_action_type_id  (user_id,post_action_type_id)
#
