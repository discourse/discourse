# frozen_string_literal: true

class DoNotDisturbTiming < ActiveRecord::Base
  belongs_to :user

  validate :ends_at_greater_thans_starts_at

  def ends_at_greater_thans_starts_at
    if starts_at > ends_at
      errors.add(:ends_at, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: do_not_disturb_timings
#
#  id        :bigint           not null, primary key
#  user_id   :integer          not null
#  starts_at :datetime         not null
#  ends_at   :datetime         not null
#  scheduled :boolean          default(FALSE)
#
# Indexes
#
#  index_do_not_disturb_timings_on_ends_at    (ends_at)
#  index_do_not_disturb_timings_on_scheduled  (scheduled)
#  index_do_not_disturb_timings_on_starts_at  (starts_at)
#  index_do_not_disturb_timings_on_user_id    (user_id)
#
