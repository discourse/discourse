require_dependency 'enum'
require_dependency 'reviewable/actions'
require_dependency 'reviewable/conversation'
require_dependency 'reviewable/editable_fields'
require_dependency 'reviewable/perform_result'
require_dependency 'reviewable_serializer'

class Reviewable < ActiveRecord::Base
  class UpdateConflict < StandardError; end

  class InvalidAction < StandardError
    def initialize(action_id, klass)
      @action_id, @klass = action_id, klass
      super("Can't peform `#{action_id}` on #{klass.name}")
    end
  end

  before_save :apply_review_group
  attr_accessor :created_new
  validates_presence_of :type, :status, :created_by_id
  belongs_to :target, polymorphic: true
  belongs_to :created_by, class_name: 'User'
  belongs_to :target_created_by, class_name: 'User'
  belongs_to :reviewable_by_group, class_name: 'Group'

  # Optional, for filtering
  belongs_to :topic
  belongs_to :category

  has_many :reviewable_histories
  has_many :reviewable_scores

  after_create do
    log_history(:created, created_by)
  end

  after_commit(on: :create) do
    DiscourseEvent.trigger(:reviewable_created, self)
    Jobs.enqueue(:notify_reviewable, reviewable_id: self.id) if pending?
  end

  def self.statuses
    @statuses ||= Enum.new(
      pending: 0,
      approved: 1,
      rejected: 2,
      ignored: 3,
      deleted: 4
    )
  end

  # Generate `pending?`, `rejected?`, etc helper methods
  statuses.each do |name, id|
    define_method("#{name}?") { status == id }
    self.class.define_method(name) { where(status: id) }
  end

  def self.default_visible
    where("score >= ?", SiteSetting.min_score_default_visibility)
  end

  def self.valid_type?(type)
    return false unless type =~ /^Reviewable[A-Za-z]+$/
    type.constantize <= Reviewable
  rescue NameError
    false
  end

  def self.types
    %w[ReviewableFlaggedPost ReviewableQueuedPost ReviewableUser]
  end

  def created_new!
    self.created_new = true
    self.topic = target.topic if topic.blank? && target.is_a?(Post)
    self.target_created_by_id = target.is_a?(Post) ? target.user_id : nil
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
    potential_spam: true
  )
    reviewable = new(
      target: target,
      topic: topic,
      created_by: created_by,
      reviewable_by_moderator: reviewable_by_moderator,
      payload: payload,
      potential_spam: potential_spam
    )
    reviewable.created_new!
    reviewable.save!
    reviewable

  rescue ActiveRecord::RecordNotUnique

    row_count = DB.exec(<<~SQL, status: statuses[:pending], id: target.id, type: target.class.name)
      UPDATE reviewables
      SET status = :status
      WHERE status <> :status
        AND target_id = :id
        AND target_type = :type
    SQL

    where(target: target).update_all(potential_spam: true) if potential_spam

    reviewable = find_by(target: target)
    reviewable.log_history(:transitioned, created_by) if row_count > 0
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
    sub_total = (ReviewableScore.user_flag_score(user) + type_bonus + take_action_bonus)

    # We can force a reviewable to hit the threshold, for example with queued posts
    if force_review && sub_total < SiteSetting.min_score_default_visibility
      sub_total = SiteSetting.min_score_default_visibility
    end

    rs = reviewable_scores.new(
      user: user,
      status: ReviewableScore.statuses[:pending],
      reviewable_score_type: reviewable_score_type,
      score: sub_total,
      meta_topic_id: meta_topic_id,
      take_action_bonus: take_action_bonus,
      created_at: created_at || Time.zone.now
    )
    rs.reason = reason.to_s if reason
    rs.save!

    update(score: self.score + rs.score, latest_score: rs.created_at)
    topic.update(reviewable_score: topic.reviewable_score + rs.score) if topic

    rs
  end

  def history
    reviewable_histories.order(:created_at)
  end

  def log_history(reviewable_history_type, performed_by, edited: nil)
    reviewable_histories.create!(
      reviewable_history_type: ReviewableHistory.types[reviewable_history_type],
      status: status,
      created_by: performed_by,
      edited: edited
    )
  end

  def apply_review_group
    return unless SiteSetting.enable_category_group_review? && category.present? && category.reviewable_by_group_id
    self.reviewable_by_group_id = category.reviewable_by_group_id
  end

  def actions_for(guardian, args = nil)
    args ||= {}
    Actions.new(self, guardian).tap { |a| build_actions(a, guardian, args) }
  end

  def editable_for(guardian, args = nil)
    args ||= {}
    EditableFields.new(self, guardian, args).tap { |a| build_editable_fields(a, guardian, args) }
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
      changes_json.delete('version')

      result = save
      log_history(:edited, performed_by, edited: changes_json) if result
    end

    result
  end

  # Delegates to a `perform_#{action_id}` method, which returns a `PerformResult` with
  # the result of the operation and whether the status of the reviewable changed.
  def perform(performed_by, action_id, args = nil)
    args ||= {}

    # Ensure the user has access to the action
    actions = actions_for(Guardian.new(performed_by), args)
    raise InvalidAction.new(action_id, self.class) unless actions.has?(action_id)

    perform_method = "perform_#{action_id}".to_sym
    raise InvalidAction.new(action_id, self.class) unless respond_to?(perform_method)

    result = nil
    update_count = false
    Reviewable.transaction do
      increment_version!(args[:version])
      result = send(perform_method, performed_by, args)

      if result.success?
        update_count = transition_to(result.transition_to, performed_by) if result.transition_to
        update_flag_stats(**result.update_flag_stats) if result.update_flag_stats

        recalculate_score if result.recalculate_score
      end
    end
    if result && result.after_commit
      result.after_commit.call
    end
    Jobs.enqueue(:notify_reviewable, reviewable_id: self.id) if update_count

    result
  end

  def transition_to(status_symbol, performed_by)
    was_pending = pending?

    self.status = Reviewable.statuses[status_symbol]
    save!

    log_history(:transitioned, performed_by)
    DiscourseEvent.trigger(:reviewable_transitioned_to, status_symbol, self)

    if score_status = ReviewableScore.score_transitions[status_symbol]
      reviewable_scores.pending.update_all(
        status: score_status,
        reviewed_by_id: performed_by.id,
        reviewed_at: Time.zone.now
      )
    end

    was_pending
  end

  def post_options
    Discourse.deprecate(
      "Reviewable#post_options is deprecated. Please use #payload instead.",
      output_in_test: true
    )
  end

  def self.bulk_perform_targets(performed_by, action, type, target_ids, args = nil)
    args ||= {}
    viewable_by(performed_by).where(type: type, target_id: target_ids).each do |r|
      r.perform(performed_by, action, args)
    end
  end

  def self.viewable_by(user, order: nil, preload: true)
    return none unless user.present?

    result = self.order(order || 'score desc, created_at desc')

    if preload
      result = result.includes(
        { created_by: :user_stat },
        :topic,
        :target,
        :target_created_by,
        :reviewable_histories
      ).includes(reviewable_scores: { user: :user_stat, meta_topic: :posts })
    end
    return result if user.admin?

    group_ids = SiteSetting.enable_category_group_review? ? user.group_users.pluck(:group_id) : []

    result.where(
      '(reviewable_by_moderator AND :staff) OR (reviewable_by_group_id IN (:group_ids))',
      staff: user.staff?,
      group_ids: group_ids
    ).where("category_id IS NULL OR category_id IN (?)", Guardian.new(user).allowed_category_ids)
  end

  def self.pending_count(user)
    list_for(user).count
  end

  def self.list_for(
    user,
    status: :pending,
    category_id: nil,
    topic_id: nil,
    type: nil,
    limit: nil,
    offset: nil,
    min_score: nil,
    username: nil
  )
    min_score ||= SiteSetting.min_score_default_visibility

    order = (status == :pending) ? 'score DESC, created_at DESC' : 'created_at DESC'

    if username.present?
      user_id = User.find_by_username(username)&.id
      return [] if user_id.blank?
    end

    return [] if user.blank?
    result = viewable_by(user, order: order)

    result = by_status(result, status)
    result = result.where(type: type) if type
    result = result.where(category_id: category_id) if category_id
    result = result.where(topic_id: topic_id) if topic_id
    result = result.where("score >= ?", min_score) if min_score

    # If a reviewable doesn't have a target, allow us to filter on who created that reviewable.
    if user_id
      result = result.where(
        "(target_created_by_id IS NULL AND created_by_id = :user_id) OR (target_created_by_id = :user_id)",
        user_id: user_id
      )
    end

    result = result.limit(limit) if limit
    result = result.offset(offset) if offset
    result
  end

  def serializer
    self.class.serializer_for(self)
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

  def self.count_by_date(start_date, end_date, category_id = nil)
    scores_with_topics
      .where('reviewable_scores.created_at BETWEEN ? AND ?', start_date, end_date)
      .where("topics.category_id = COALESCE(?, topics.category_id)", category_id)
      .group("date(reviewable_scores.created_at)")
      .order('date(reviewable_scores.created_at)')
      .count
  end

protected

  def recalculate_score
    # Recalculate the pending score and return it
    result = DB.query(<<~SQL, id: self.id, pending: ReviewableScore.statuses[:pending])
      UPDATE reviewables
      SET score = COALESCE((
        SELECT sum(score)
        FROM reviewable_scores AS rs
        WHERE rs.reviewable_id = :id
      ), 0.0)
      WHERE id = :id
      RETURNING score
    SQL

    # Update topic score
    DB.query(<<~SQL, topic_id: topic_id, pending: Reviewable.statuses[:pending])
      UPDATE topics
      SET reviewable_score = COALESCE((
        SELECT SUM(score)
        FROM reviewables AS r
        WHERE r.topic_id = :topic_id
      ), 0.0)
      WHERE id = :topic_id
    SQL

    self.score = result[0].score
  end

  def increment_version!(version = nil)
    version_result = nil

    if version
      version_result = DB.query_single(
        "UPDATE reviewables SET version = version + 1 WHERE id = :id AND version = :version RETURNING version",
        version: version,
        id: self.id
      )
    else
      # We didn't supply a version to update safely, so just increase it
      version_result = DB.query_single(
        "UPDATE reviewables SET version = version + 1 WHERE id = :id RETURNING version",
        id: self.id
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
      partial_result.where(status: [statuses[:approved], statuses[:rejected], statuses[:ignored]])
    else
      partial_result.where(status: statuses[status])
    end
  end

private

  def update_flag_stats(status:, user_ids:)
    return unless [:agreed, :disagreed, :ignored].include?(status)

    # Don't count self-flags
    user_ids -= [post&.user_id]
    return if user_ids.blank?

    result = DB.query(<<~SQL, user_ids: user_ids)
      UPDATE user_stats
      SET flags_#{status} = flags_#{status} + 1
      WHERE user_id IN (:user_ids)
      RETURNING user_id, flags_agreed + flags_disagreed + flags_ignored AS total
    SQL

    user_ids = result.select { |r| r.total > Jobs::TruncateUserFlagStats.truncate_to }.map(&:user_id)
    return if user_ids.blank?

    Jobs.enqueue(:truncate_user_flag_stats, user_ids: user_ids)
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint(8)        not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  claimed_by_id           :integer
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
#
# Indexes
#
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
