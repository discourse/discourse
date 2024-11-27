# frozen_string_literal: true

class Reviewable < ActiveRecord::Base
  TYPE_TO_BASIC_SERIALIZER = {
    ReviewableFlaggedPost: BasicReviewableFlaggedPostSerializer,
    ReviewableQueuedPost: BasicReviewableQueuedPostSerializer,
    ReviewableUser: BasicReviewableUserSerializer,
  }

  self.ignored_columns = [:reviewable_by_group_id]

  class UpdateConflict < StandardError
  end

  class InvalidAction < StandardError
    def initialize(action_id, klass)
      @action_id, @klass = action_id, klass
      super("Can't perform `#{action_id}` on #{klass.name}")
    end
  end

  attr_accessor :created_new
  validates_presence_of :type, :status, :created_by_id
  belongs_to :target, polymorphic: true
  belongs_to :created_by, class_name: "User"
  belongs_to :target_created_by, class_name: "User"

  # Optional, for filtering
  belongs_to :topic
  belongs_to :category

  has_many :reviewable_histories, dependent: :destroy
  has_many :reviewable_scores, -> { order(created_at: :desc) }, dependent: :destroy

  enum :status, { pending: 0, approved: 1, rejected: 2, ignored: 3, deleted: 4 }

  attribute :sensitivity, :integer
  enum :sensitivity, { disabled: 0, low: 9, medium: 6, high: 3 }, scopes: false, suffix: true

  attribute :priority, :integer
  enum :priority, { low: 0, medium: 5, high: 10 }, scopes: false, suffix: true

  validates :reject_reason, length: { maximum: 2000 }

  after_create { log_history(:created, created_by) }

  after_commit(on: :create) { DiscourseEvent.trigger(:reviewable_created, self) }

  after_commit(on: %i[create update]) do
    Jobs.enqueue(:notify_reviewable, reviewable_id: self.id) if pending?
  end

  # Can be used if several actions are equivalent
  def self.action_aliases
    {}
  end

  # This number comes from looking at forums in the wild and what numbers work.
  # As the site accumulates real data it'll be based on the site activity instead.
  def self.typical_sensitivity
    12.5
  end

  def self.default_visible
    where("score >= ?", min_score_for_priority)
  end

  def self.valid_type?(type)
    type.to_s.safe_constantize.in?(types)
  end

  def self.types
    [ReviewableFlaggedPost, ReviewableQueuedPost, ReviewableUser, ReviewablePost]
  end

  def self.custom_filters
    @reviewable_filters ||= []
  end

  def self.add_custom_filter(new_filter)
    custom_filters << new_filter
  end

  def self.clear_custom_filters!
    @reviewable_filters = []
  end

  def created_new!
    self.created_new = true
    self.topic = target.topic if topic.blank? && target.is_a?(Post)
    self.target_created_by_id ||= target.is_a?(Post) ? target.user_id : nil
    self.category_id = topic.category_id if category_id.blank? && topic.present?
  end

  # Create a new reviewable, or if the target has already been reviewed return it to the
  # pending state and re-use it.
  #
  # You probably want to call this to create your reviewable rather than `.create`.
  def self.needs_review!(
    target: nil,
    topic: nil,
    created_by:,
    payload: nil,
    reviewable_by_moderator: false,
    potential_spam: true,
    potentially_illegal: false,
    target_created_by: nil
  )
    reviewable =
      new(
        target: target,
        topic: topic,
        created_by: created_by,
        reviewable_by_moderator: reviewable_by_moderator,
        payload: payload,
        potential_spam: potential_spam,
        potentially_illegal: potentially_illegal,
        target_created_by: target_created_by,
      )
    reviewable.created_new!

    if target.blank? || !Reviewable.where(target: target, type: reviewable.type).exists?
      # If there is no target, or no existing reviewable with matching target and type, there's no chance of a conflict
      reviewable.save!
    else
      # In this case, a reviewable might already exist for this (type, target_id) index.
      # ActiveRecord can only validate indexes using a SELECT before the INSERT which
      # is not safe under concurrency. Instead, we perform an UPDATE on the status, and return
      # the previous value. We then know:
      #
      #   a) if a previous row existed
      #   b) if it was changed
      #
      # And that allows us to complete our logic.

      update_args = {
        status: statuses[:pending],
        id: target.id,
        type: target.class.polymorphic_name,
        potential_spam: potential_spam == true ? true : nil,
        potentially_illegal: potentially_illegal == true ? true : nil,
      }

      row = DB.query_single(<<~SQL, update_args)
        UPDATE reviewables
        SET status = :status,
          potential_spam = COALESCE(:potential_spam, reviewables.potential_spam),
          potentially_illegal = COALESCE(:potentially_illegal, reviewables.potentially_illegal)
        FROM reviewables AS old_reviewables
        WHERE reviewables.target_id = :id
          AND reviewables.target_type = :type
        RETURNING old_reviewables.status
      SQL
      old_status = row[0]

      if old_status.blank?
        reviewable.save!
      else
        reviewable = find_by(target: target)

        if old_status != statuses[:pending]
          # If we're transitioning back from reviewed to pending, we should recalculate
          # the score to prevent posts from being hidden.
          reviewable.recalculate_score
          reviewable.log_history(:transitioned, created_by)
        end
      end
    end

    reviewable
  end

  def add_score(
    user,
    reviewable_score_type,
    reason: nil,
    created_at: nil,
    take_action: false,
    meta_topic_id: nil,
    force_review: false
  )
    type_bonus = PostActionType.where(id: reviewable_score_type).pluck(:score_bonus)[0] || 0
    take_action_bonus = take_action ? 5.0 : 0.0
    user_accuracy_bonus = ReviewableScore.user_accuracy_bonus(user)
    sub_total = ReviewableScore.calculate_score(user, type_bonus, take_action_bonus)

    rs =
      reviewable_scores.new(
        user: user,
        status: :pending,
        reviewable_score_type: reviewable_score_type,
        score: sub_total,
        user_accuracy_bonus: user_accuracy_bonus,
        meta_topic_id: meta_topic_id,
        take_action_bonus: take_action_bonus,
        created_at: created_at || Time.zone.now,
      )
    rs.reason = reason.to_s if reason
    rs.save!

    update(score: self.score + rs.score, latest_score: rs.created_at, force_review: force_review)
    topic.update(reviewable_score: topic.reviewable_score + rs.score) if topic

    # Flags are cached for performance reasons.
    # However, when the reviewable item is created, we need to clear the cache to mark flag as used.
    # Used flags cannot be deleted or update by admins, only disabled.
    Flag.reset_flag_settings! if PostActionType.notify_flag_type_ids.include?(reviewable_score_type)

    DiscourseEvent.trigger(:reviewable_score_updated, self)

    rs
  end

  def self.set_priorities(values)
    values.each do |k, v|
      id = priorities[k]
      PluginStore.set("reviewables", "priority_#{id}", v) unless id.nil?
    end
  end

  def self.sensitivity_score_value(sensitivity, scale)
    return Float::MAX if sensitivity == 0

    ratio = sensitivity / sensitivities[:low].to_f
    high =
      (PluginStore.get("reviewables", "priority_#{priorities[:high]}") || typical_sensitivity).to_f

    # We want this to be hard to reach
    ((high.to_f * ratio) * scale).truncate(2)
  end

  def self.sensitivity_score(sensitivity, scale: 1.0)
    # If the score is less than the default visibility, bring it up to that level.
    # Otherwise we have the confusing situation where a post might be hidden and
    # moderators would never see it!
    [sensitivity_score_value(sensitivity, scale), min_score_for_priority].max
  end

  def self.score_to_auto_close_topic
    sensitivity_score(SiteSetting.auto_close_topic_sensitivity, scale: 2.5)
  end

  def self.spam_score_to_silence_new_user
    sensitivity_score(SiteSetting.silence_new_user_sensitivity, scale: 0.6)
  end

  def self.score_required_to_hide_post
    sensitivity_score(SiteSetting.hide_post_sensitivity)
  end

  def self.min_score_for_priority(priority = nil)
    priority ||= SiteSetting.reviewable_default_visibility
    id = priorities[priority]
    return 0.0 if id.nil?
    PluginStore.get("reviewables", "priority_#{id}").to_f
  end

  def history
    reviewable_histories.order(:created_at)
  end

  def log_history(reviewable_history_type, performed_by, edited: nil)
    reviewable_histories.create!(
      reviewable_history_type: reviewable_history_type,
      status: status,
      created_by: performed_by,
      edited: edited,
    )
  end

  def actions_for(guardian, args = nil)
    args ||= {}

    Actions.new(self, guardian).tap { |actions| build_actions(actions, guardian, args) }
  end

  def editable_for(guardian, args = nil)
    args ||= {}
    EditableFields
      .new(self, guardian, args)
      .tap { |fields| build_editable_fields(fields, guardian, args) }
  end

  # subclasses must implement "build_actions" to list the actions they're capable of
  def build_actions(actions, guardian, args)
    raise NotImplementedError
  end

  # subclasses can implement "build_editable_fields" to list stuff that can be edited
  def build_editable_fields(actions, guardian, args)
  end

  def update_fields(params, performed_by, version: nil)
    return true if params.blank?

    (params[:payload] || {}).each { |k, v| self.payload[k] = v }
    self.category_id = params[:category_id] if params.has_key?(:category_id)

    result = false

    Reviewable.transaction do
      increment_version!(version)
      changes_json = changes.as_json
      changes_json.delete("version")

      result = save
      log_history(:edited, performed_by, edited: changes_json) if result
    end

    result
  end

  # Delegates to a `perform_#{action_id}` method, which returns a `PerformResult` with
  # the result of the operation and whether the status of the reviewable changed.
  def perform(performed_by, action_id, args = nil)
    args ||= {}
    # Support this action or any aliases
    aliases = self.class.action_aliases
    valid = [action_id, aliases.to_a.select { |k, v| v == action_id }.map(&:first)].flatten

    # Ensure the user has access to the action
    actions = actions_for(args[:guardian] || Guardian.new(performed_by), args)
    raise InvalidAction.new(action_id, self.class) unless valid.any? { |a| actions.has?(a) }

    perform_method = "perform_#{aliases[action_id] || action_id}".to_sym
    raise InvalidAction.new(action_id, self.class) unless respond_to?(perform_method)

    result = nil
    update_count = false
    Reviewable.transaction do
      increment_version!(args[:version])
      result = public_send(perform_method, performed_by, args)

      raise ActiveRecord::Rollback unless result.success?

      update_count = transition_to(result.transition_to, performed_by) if result.transition_to
      update_flag_stats(**result.update_flag_stats) if result.update_flag_stats

      recalculate_score if result.recalculate_score
    end
    result.after_commit.call if result && result.after_commit

    if update_count || result.remove_reviewable_ids.present?
      Jobs.enqueue(
        :notify_reviewable,
        reviewable_id: self.id,
        performing_username: performed_by.username,
        updated_reviewable_ids: result.remove_reviewable_ids,
      )
    end

    result
  end

  # Override this in specific reviewable type to include scores for
  # non-pending reviewables
  def updatable_reviewable_scores
    reviewable_scores.pending
  end

  def transition_to(status_symbol, performed_by)
    self.status = status_symbol
    save!

    log_history(:transitioned, performed_by)
    DiscourseEvent.trigger(:reviewable_transitioned_to, status_symbol, self)

    if score_status = ReviewableScore.score_transitions[status_symbol]
      updatable_reviewable_scores.update_all(
        status: score_status,
        reviewed_by_id: performed_by.id,
        reviewed_at: Time.zone.now,
      )
    end

    status_previously_changed?(from: "pending")
  end

  def self.bulk_perform_targets(performed_by, action, type, target_ids, args = nil)
    args ||= {}
    viewable_by(performed_by)
      .where(type: type, target_id: target_ids)
      .each { |r| r.perform(performed_by, action, args) }
  end

  def self.viewable_by(user, order: nil, preload: true)
    return none if user.blank?

    result = self.order(order || "reviewables.score desc, reviewables.created_at desc")

    if preload
      result =
        result.includes(
          { created_by: :user_stat },
          :topic,
          :target,
          :target_created_by,
          :reviewable_histories,
        ).includes(reviewable_scores: { user: :user_stat, meta_topic: :posts })
    end
    return result if user.admin?

    group_ids =
      SiteSetting.enable_category_group_moderation? ? user.group_users.pluck(:group_id) : []

    result
      .left_joins(category: :category_moderation_groups)
      .where(
        "(reviewables.reviewable_by_moderator AND :moderator) OR (category_moderation_groups.group_id IN (:group_ids))",
        moderator: user.moderator?,
        group_ids: group_ids,
      )
      .where(
        "reviewables.category_id IS NULL OR reviewables.category_id IN (?)",
        Guardian.new(user).allowed_category_ids,
      )
  end

  def self.pending_count(user)
    list_for(user).count
  end

  def self.unseen_reviewable_count(user)
    self.unseen_list_for(user).count
  end

  def self.list_for(
    user,
    ids: nil,
    status: :pending,
    category_id: nil,
    topic_id: nil,
    type: nil,
    limit: nil,
    offset: nil,
    priority: nil,
    username: nil,
    reviewed_by: nil,
    sort_order: nil,
    from_date: nil,
    to_date: nil,
    additional_filters: {},
    preload: true,
    include_claimed_by_others: true
  )
    order =
      case sort_order
      when "score_asc"
        "reviewables.score ASC, reviewables.created_at DESC"
      when "created_at"
        "reviewables.created_at DESC, reviewables.score DESC"
      when "created_at_asc"
        "reviewables.created_at ASC, reviewables.score DESC"
      else
        "reviewables.score DESC, reviewables.created_at DESC"
      end

    if username.present?
      user_id = User.find_by_username(username)&.id
      return none if user_id.blank?
    end

    return none if user.blank?
    result = viewable_by(user, order: order, preload: preload)

    result = by_status(result, status)
    result = result.where(id: ids) if ids

    result = result.where("reviewables.type = ?", Reviewable.sti_class_for(type).sti_name) if type
    result = result.where("reviewables.category_id = ?", category_id) if category_id
    result = result.where("reviewables.topic_id = ?", topic_id) if topic_id
    result = result.where("reviewables.created_at >= ?", from_date) if from_date
    result = result.where("reviewables.created_at <= ?", to_date) if to_date

    if reviewed_by
      reviewed_by_id = User.find_by_username(reviewed_by)&.id
      return none if reviewed_by_id.nil?

      result = result.joins(<<~SQL)
        INNER JOIN(
          SELECT reviewable_id
          FROM reviewable_histories
          WHERE reviewable_history_type = #{ReviewableHistory.types[:transitioned]} AND
          status <> #{statuses[:pending]} AND created_by_id = #{reviewed_by_id}
        ) AS rh ON rh.reviewable_id = reviewables.id
      SQL
    end

    min_score = min_score_for_priority(priority)

    if min_score > 0 && status == :pending
      result = result.where("reviewables.score >= ? OR reviewables.force_review", min_score)
    elsif min_score > 0
      result = result.where("reviewables.score >= ?", min_score)
    end

    if !custom_filters.empty?
      result =
        custom_filters.reduce(result) do |memo, filter|
          key = filter.first
          filter_query = filter.last

          next(memo) unless additional_filters[key]
          filter_query.call(result, additional_filters[key])
        end
    end

    # If a reviewable doesn't have a target, allow us to filter on who created that reviewable.
    # A ReviewableQueuedPost may have a target_created_by_id even before a target get's assigned
    if user_id
      result =
        result.where(
          "(reviewables.target_id IS NULL AND reviewables.created_by_id = :user_id)
        OR (reviewables.target_created_by_id = :user_id)",
          user_id: user_id,
        )
    end

    if !include_claimed_by_others
      result =
        result.joins(
          "LEFT JOIN reviewable_claimed_topics rct ON reviewables.topic_id = rct.topic_id",
        ).where("rct.user_id IS NULL OR rct.user_id = ?", user.id)
    end
    result = result.limit(limit) if limit
    result = result.offset(offset) if offset
    result
  end

  def self.unseen_list_for(user, preload: true, limit: nil)
    results = list_for(user, preload: preload, limit: limit, include_claimed_by_others: false)
    if user.last_seen_reviewable_id
      results = results.where("reviewables.id > ?", user.last_seen_reviewable_id)
    end
    results
  end

  def self.user_menu_list_for(user, limit: 30)
    list_for(user, limit: limit, status: :pending, include_claimed_by_others: false).to_a
  end

  def self.basic_serializers_for_list(reviewables, user)
    reviewables.map { |r| r.basic_serializer.new(r, scope: user.guardian, root: nil) }
  end

  def serializer
    self.class.serializer_for(self)
  end

  def basic_serializer
    TYPE_TO_BASIC_SERIALIZER[self.type.to_sym] || BasicReviewableSerializer
  end

  def type_class
    Reviewable.sti_class_for(self.type)
  end

  def self.lookup_serializer_for(type)
    "#{type}Serializer".constantize
  rescue NameError
    ReviewableSerializer
  end

  def self.serializer_for(reviewable)
    type = reviewable.type
    @@serializers ||= {}
    @@serializers[type] ||= lookup_serializer_for(type)
  end

  def create_result(status, transition_to = nil)
    result = PerformResult.new(self, status)
    result.transition_to = transition_to
    yield result if block_given?
    result
  end

  def self.scores_with_topics
    ReviewableScore.joins(reviewable: :topic).where("reviewables.type = ?", name)
  end

  def self.count_by_date(start_date, end_date, category_id = nil, include_subcategories = false)
    query =
      scores_with_topics.where("reviewable_scores.created_at BETWEEN ? AND ?", start_date, end_date)

    if category_id
      if include_subcategories
        query = query.where("topics.category_id IN (?)", Category.subcategory_ids(category_id))
      else
        query = query.where("topics.category_id = ?", category_id)
      end
    end

    query
      .group("date(reviewable_scores.created_at)")
      .order("date(reviewable_scores.created_at)")
      .count
  end

  def explain_score
    DB.query(<<~SQL, reviewable_id: id)
      SELECT rs.reviewable_id,
        rs.user_id,
        CASE WHEN (u.admin OR u.moderator) THEN 5.0 ELSE u.trust_level END AS trust_level_bonus,
        us.flags_agreed,
        us.flags_disagreed,
        us.flags_ignored,
        rs.score,
        rs.user_accuracy_bonus,
        rs.take_action_bonus,
        COALESCE(pat.score_bonus, 0.0) AS type_bonus
      FROM reviewable_scores AS rs
      INNER JOIN users AS u ON u.id = rs.user_id
      LEFT OUTER JOIN user_stats AS us ON us.user_id = rs.user_id
      LEFT OUTER JOIN post_action_types AS pat ON pat.id = rs.reviewable_score_type
        WHERE rs.reviewable_id = :reviewable_id
    SQL
  end

  def recalculate_score
    # pending/agreed scores count
    sql = <<~SQL
      UPDATE reviewables
      SET score = COALESCE((
        SELECT sum(score)
        FROM reviewable_scores AS rs
        WHERE rs.reviewable_id = :id
          AND rs.status IN (:pending, :agreed)
      ), 0.0)
      WHERE id = :id
      RETURNING score
    SQL

    result =
      DB.query(
        sql,
        id: self.id,
        pending: ReviewableScore.statuses[:pending],
        agreed: ReviewableScore.statuses[:agreed],
      )

    # Update topic score
    sql = <<~SQL
      UPDATE topics
      SET reviewable_score = COALESCE((
        SELECT SUM(score)
        FROM reviewables AS r
        WHERE r.topic_id = :topic_id
          AND r.status IN (:pending, :approved)
      ), 0.0)
      WHERE id = :topic_id
    SQL

    DB.query(
      sql,
      topic_id: topic_id,
      pending: self.class.statuses[:pending],
      approved: self.class.statuses[:approved],
    )

    self.score = result[0].score

    DiscourseEvent.trigger(:reviewable_score_updated, self)

    self.score
  end

  def delete_user_actions(actions, bundle = nil, require_reject_reason: false)
    bundle ||=
      actions.add_bundle(
        "reject_user",
        icon: "user-xmark",
        label: "reviewables.actions.reject_user.title",
      )

    actions.add(:delete_user, bundle: bundle) do |a|
      a.icon = "user-xmark"
      a.label = "reviewables.actions.reject_user.delete.title"
      a.require_reject_reason = require_reject_reason
    end

    actions.add(:delete_user_block, bundle: bundle) do |a|
      a.icon = "ban"
      a.label = "reviewables.actions.reject_user.block.title"
      a.require_reject_reason = require_reject_reason
      a.description = "reviewables.actions.reject_user.block.description"
    end
  end

  protected

  def increment_version!(version = nil)
    version_result = nil

    if version
      version_result =
        DB.query_single(
          "UPDATE reviewables SET version = version + 1 WHERE id = :id AND version = :version RETURNING version",
          version: version,
          id: self.id,
        )
    else
      # We didn't supply a version to update safely, so just increase it
      version_result =
        DB.query_single(
          "UPDATE reviewables SET version = version + 1 WHERE id = :id RETURNING version",
          id: self.id,
        )
    end

    if version_result && version_result[0]
      self.version = version_result[0]
    else
      raise UpdateConflict.new
    end
  end

  def self.by_status(partial_result, status)
    return partial_result if status == :all

    if status == :reviewed
      partial_result.where(status: statuses.except(:pending).values)
    else
      partial_result.where(status: statuses[status])
    end
  end

  def self.find_by_flagger_or_queued_post_creator(id:, user_id:)
    Reviewable.find_by(
      "id = :id AND (created_by_id = :user_id
       OR (target_created_by_id = :user_id AND type = 'ReviewableQueuedPost'))",
      id: id,
      user_id: user_id,
    )
  end

  private

  def update_flag_stats(status:, user_ids:)
    return if %i[agreed disagreed ignored].exclude?(status)

    # Don't count self-flags
    user_ids -= [post&.user_id]
    return if user_ids.blank?

    result = DB.query(<<~SQL, user_ids: user_ids)
      UPDATE user_stats
      SET flags_#{status} = flags_#{status} + 1
      WHERE user_id IN (:user_ids)
      RETURNING user_id, flags_agreed + flags_disagreed + flags_ignored AS total
    SQL

    user_ids =
      result.select { |r| r.total > Jobs::TruncateUserFlagStats.truncate_to }.map(&:user_id)
    return if user_ids.blank?

    Jobs.enqueue(:truncate_user_flag_stats, user_ids: user_ids)
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
