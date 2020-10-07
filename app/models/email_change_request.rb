# frozen_string_literal: true

class EmailChangeRequest < ActiveRecord::Base
  belongs_to :old_email_token, class_name: 'EmailToken'
  belongs_to :new_email_token, class_name: 'EmailToken'
  belongs_to :user
  belongs_to :requested_by, class_name: "User", foreign_key: :requested_by_user_id

  validates :new_email, presence: true, format: { with: EmailValidator.email_regex }

  def self.states
    @states ||= Enum.new(authorizing_old: 1, authorizing_new: 2, complete: 3)
  end

  def requested_by_admin?
    self.requested_by.admin? && !self.requested_by_self?
  end

  def requested_by_self?
    self.requested_by == self.user
  end
end

# == Schema Information
#
# Table name: email_change_requests
#
#  id                   :integer          not null, primary key
#  user_id              :integer          not null
#  old_email            :string
#  new_email            :string           not null
#  old_email_token_id   :integer
#  new_email_token_id   :integer
#  change_state         :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  requested_by_user_id :integer
#
# Indexes
#
#  idx_email_change_requests_on_requested_by  (requested_by_user_id)
#  index_email_change_requests_on_user_id     (user_id)
#
