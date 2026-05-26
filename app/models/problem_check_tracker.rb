# frozen_string_literal: true

class ProblemCheckTracker < ActiveRecord::Base
  validates :identifier, presence: true, uniqueness: { scope: :target }
  validates :target, presence: true
  validates :blips, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :failing, -> { where("last_problem_at = last_run_at") }
  scope :passing, -> { where("last_success_at = last_run_at") }
  scope :ignored, -> { where.not(ignored_at: nil) }
  scope :watched, -> { where(ignored_at: nil) }

  before_destroy :silence_the_alarm

  def self.[](identifier, target = ProblemCheck::NO_TARGET)
    find_or_create_by(identifier:, target:)
  end

  def ready_to_run?
    next_run_at.blank? || next_run_at.past?
  end

  def failing?
    last_problem_at == last_run_at
  end

  def passing?
    last_success_at == last_run_at
  end

  def ignored?
    ignored_at.present?
  end

  def watched?
    !ignored?
  end

  def ignore!
    return if ignored?

    touch(:ignored_at)
    silence_the_alarm
  end

  def watch!
    return if watched?

    update!(ignored_at: nil)
    sound_the_alarm if sound_the_alarm?
  end

  def problem!(next_run_at: nil, details: {})
    now = Time.current

    update!(blips: blips + 1, details:, last_run_at: now, last_problem_at: now, next_run_at:)

    update_notice_details(details)

    sound_the_alarm if sound_the_alarm?
  end

  def no_problem!(next_run_at: nil)
    reset(next_run_at:)
    silence_the_alarm
  end

  def check
    check = ProblemCheck[identifier]

    return check if check.present?

    silence_the_alarm
    destroy

    nil
  end

  private

  def reset(next_run_at: nil)
    now = Time.current

    update!(blips: 0, last_run_at: now, last_success_at: now, next_run_at:)
  end

  def update_notice_details(details)
    admin_notice.where(identifier:).update_all(details: details.merge(target:))
  end

  def sound_the_alarm?
    watched? && failing? && blips > check.max_blips
  end

  def sound_the_alarm
    admin_notice.create_with(
      priority: check.priority,
      details: details.merge(target:),
    ).find_or_create_by(identifier:)
  end

  def silence_the_alarm
    admin_notice.where(identifier:).delete_all
  end

  def admin_notice
    AdminNotice.problem.where("details->>'target' = ?", target)
  end
end

# == Schema Information
#
# Table name: problem_check_trackers
#
#  id              :bigint           not null, primary key
#  blips           :integer          default(0), not null
#  details         :json
#  identifier      :string           not null
#  ignored_at      :datetime
#  last_problem_at :datetime
#  last_run_at     :datetime
#  last_success_at :datetime
#  next_run_at     :datetime
#  target          :string           default("__NULL__"), not null
#
# Indexes
#
#  index_problem_check_trackers_on_identifier_and_target  (identifier,target) UNIQUE
#
