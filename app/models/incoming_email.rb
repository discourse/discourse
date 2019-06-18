# frozen_string_literal: true

class IncomingEmail < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :post

  scope :errored,  -> { where("NOT is_bounce AND error IS NOT NULL") }

  scope :addressed_to, -> (email) do
    where(<<~SQL, email: "%#{email}%")
      incoming_emails.to_addresses ILIKE :email OR
      incoming_emails.cc_addresses ILIKE :email
    SQL
  end

  scope :addressed_to_user, ->(user) do
    where(<<~SQL, user_id: user.id)
      EXISTS(
          SELECT 1
          FROM user_emails
          WHERE user_emails.user_id = :user_id AND
                (incoming_emails.to_addresses ILIKE '%' || user_emails.email || '%' OR
                 incoming_emails.cc_addresses ILIKE '%' || user_emails.email || '%')
      )
    SQL
  end
end

# == Schema Information
#
# Table name: incoming_emails
#
#  id                :integer          not null, primary key
#  user_id           :integer
#  topic_id          :integer
#  post_id           :integer
#  raw               :text
#  error             :text
#  message_id        :text
#  from_address      :text
#  to_addresses      :text
#  cc_addresses      :text
#  subject           :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  rejection_message :text
#  is_auto_generated :boolean          default(FALSE)
#  is_bounce         :boolean          default(FALSE), not null
#
# Indexes
#
#  index_incoming_emails_on_created_at  (created_at)
#  index_incoming_emails_on_error       (error)
#  index_incoming_emails_on_message_id  (message_id)
#  index_incoming_emails_on_post_id     (post_id)
#  index_incoming_emails_on_user_id     (user_id) WHERE (user_id IS NOT NULL)
#
