# frozen_string_literal: true

class EmailChangeRequest < ActiveRecord::Base
  belongs_to :old_email_token, class_name: 'EmailToken'
  belongs_to :new_email_token, class_name: 'EmailToken'
  belongs_to :user

  validates :old_email, presence: true
  validates :new_email, presence: true, format: { with: EmailValidator.email_regex }

  def self.states
    @states ||= Enum.new(authorizing_old: 1, authorizing_new: 2, complete: 3)
  end

end

# == Schema Information
#
# Table name: email_change_requests
#
#  id                 :integer          not null, primary key
#  user_id            :integer          not null
#  old_email          :string           not null
#  new_email          :string           not null
#  old_email_token_id :integer
#  new_email_token_id :integer
#  change_state       :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_email_change_requests_on_user_id  (user_id)
#
