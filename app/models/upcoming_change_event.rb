# frozen_string_literal: true

class UpcomingChangeEvent < ActiveRecord::Base
  belongs_to :acting_user, class_name: "User", foreign_key: "acting_user_id"

  validates :event_type, presence: true
  validates :upcoming_change_name, presence: true

  enum :event_type,
       {
         added: 0,
         removed: 1,
         automatically_promoted: 2,
         manual_opt_in: 3,
         manual_opt_out: 4,
         status_changed: 5,
       }

  scope :added_changes, -> { where(event_type: :added).order(created_at: :desc) }
  scope :removed_changes, -> { where(event_type: :removed).order(created_at: :desc) }
end

# == Schema Information
#
# Table name: upcoming_change_events
#
#  id                   :bigint           not null, primary key
#  event_data           :json
#  event_type           :integer          not null
#  upcoming_change_name :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  acting_user_id       :bigint
#
# Indexes
#
#  index_upcoming_change_events_on_event_type            (event_type)
#  index_upcoming_change_events_on_upcoming_change_name  (upcoming_change_name)
#
