# frozen_string_literal: true

class Poll < ActiveRecord::Base
  # because we want to use the 'type' column and don't want to use STI
  self.inheritance_column = nil

  belongs_to :post, -> { with_deleted }

  has_many :poll_options, -> { order(:id) }, dependent: :destroy
  has_many :poll_votes

  enum :type, { regular: 0, multiple: 1, number: 2, ranked_choice: 3 }, scopes: false
  enum :status, { open: 0, closed: 1 }, scopes: false
  enum :results, { always: 0, on_vote: 1, on_close: 2, staff_only: 3 }, scopes: false
  enum :visibility, { secret: 0, everyone: 1 }, scopes: false
  enum :chart_type, { bar: 0, pie: 1 }, scopes: false

  validates :min, numericality: { allow_nil: true, only_integer: true, greater_than_or_equal_to: 0 }
  validates :max, numericality: { allow_nil: true, only_integer: true, greater_than: 0 }
  validates :step, numericality: { allow_nil: true, only_integer: true, greater_than: 0 }

  attr_writer :voters_count
  attr_accessor :has_voted
  attr_accessor :serialized_voters_cache

  after_initialize { @has_voted = {} }

  def reload
    @has_voted = {}
    super
  end

  def is_closed?
    closed? || (close_at && close_at <= Time.zone.now)
  end

  def can_see_results?(user)
    return !!user&.staff? if staff_only?
    !!(always? || (on_vote? && (is_me?(user) || has_voted?(user))) || is_closed?)
  end

  def is_me?(user)
    user && post && post.user&.id == user&.id
  end

  def has_voted?(user)
    if user&.id
      return @has_voted[user.id] if @has_voted.key?(user.id)

      @has_voted[user.id] = poll_votes.where(user_id: user.id).exists?
    end
  end

  def voters_count
    return @voters_count if defined?(@voters_count)

    @voters_count = poll_votes.count("DISTINCT user_id")
  end

  def can_see_voters?(user)
    everyone? && can_see_results?(user)
  end

  def ranked_choice?
    type == "ranked_choice"
  end

  def self.preload!(polls, user_id: nil)
    poll_ids = polls.map(&:id)

    voters_count =
      PollVote
        .where(poll_id: poll_ids)
        .group(:poll_id)
        .pluck(:poll_id, "COUNT(DISTINCT user_id)")
        .to_h

    option_voters_count =
      PollVote
        .where(poll_option_id: PollOption.where(poll_id: poll_ids).select(:id))
        .group(:poll_option_id)
        .pluck(:poll_option_id, "COUNT(*)")
        .to_h

    polls.each do |poll|
      poll.voters_count = voters_count[poll.id] || 0
      poll.poll_options.each do |poll_option|
        poll_option.voters_count = option_voters_count[poll_option.id] || 0
      end
    end

    if user_id
      has_voted = PollVote.where(poll_id: poll_ids, user_id: user_id).pluck(:poll_id).to_set
      polls.each { |poll| poll.has_voted[user_id] = has_voted.include?(poll.id) }
    end
  end
end

# == Schema Information
#
# Table name: polls
#
#  id               :bigint           not null, primary key
#  post_id          :bigint
#  name             :string           default("poll"), not null
#  close_at         :datetime
#  type             :integer          default("regular"), not null
#  status           :integer          default("open"), not null
#  results          :integer          default("always"), not null
#  visibility       :integer          default("secret"), not null
#  min              :integer
#  max              :integer
#  step             :integer
#  anonymous_voters :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  chart_type       :integer          default("bar"), not null
#  groups           :string
#  title            :string
#
# Indexes
#
#  index_polls_on_post_id           (post_id)
#  index_polls_on_post_id_and_name  (post_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (post_id => posts.id)
#
