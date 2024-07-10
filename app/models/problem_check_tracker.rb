# frozen_string_literal: true

class ProblemCheckTracker < ActiveRecord::Base
  validates :identifier, presence: true, uniqueness: { scope: :target }
  validates :blips, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :failing, -> { where("last_problem_at = last_run_at") }
  scope :passing, -> { where("last_success_at = last_run_at") }

  def self.[](identifier, target = nil)
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

  def problem!(next_run_at: nil, details: {})
    now = Time.current

    update!(blips: blips + 1, details:, last_run_at: now, last_problem_at: now, next_run_at:)

    sound_the_alarm if sound_the_alarm?
  end

  def no_problem!(next_run_at: nil)
    now = Time.current

    update!(blips: 0, last_run_at: now, last_success_at: now, next_run_at:)

    silence_the_alarm
  end

  def check
    ProblemCheck[identifier]
  end

  private

  def sound_the_alarm?
    failing? && blips > check.max_blips
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
    if target.present?
      AdminNotice.problem.where("details->>'target' = ?", target)
    else
      AdminNotice.problem.where("(details->>'target') IS NULL")
    end
  end
end

# == Schema Information
#
# Table name: problem_check_trackers
#
#  id              :bigint           not null, primary key
#  identifier      :string           not null
#  blips           :integer          default(0), not null
#  last_run_at     :datetime
#  next_run_at     :datetime
#  last_success_at :datetime
#  last_problem_at :datetime
#  details         :json
#  target          :string
#
# Indexes
#
#  index_problem_check_trackers_on_identifier_and_target  (identifier,target) UNIQUE
#
