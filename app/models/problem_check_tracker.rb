# frozen_string_literal: true

class ProblemCheckTracker < ActiveRecord::Base
  validates :identifier, presence: true, uniqueness: true
  validates :blips, presence: true, numericality: { greater_than_or_equal_to: 0 }

<<<<<<< HEAD
=======
  scope :failing, -> { where("last_problem_at = last_run_at") }
  scope :passing, -> { where("last_success_at = last_run_at") }

>>>>>>> 4e09b0aa7f (AdminNotice)
  def self.[](identifier)
    find_or_create_by(identifier:)
  end

  def ready_to_run?
    next_run_at.blank? || next_run_at.past?
  end

  def problem!(next_run_at: nil)
    now = Time.current

    update!(blips: blips + 1, last_run_at: now, last_problem_at: now, next_run_at:)
  end

  def no_problem!(next_run_at: nil)
    now = Time.current

    update!(blips: 0, last_run_at: now, last_success_at: now, next_run_at:)
  end

  def check
    ProblemCheck[identifier]
  end

  private

  def sound_the_alarm?
    blips > check.max_blips
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
#
# Indexes
#
#  index_problem_check_trackers_on_identifier  (identifier) UNIQUE
#
