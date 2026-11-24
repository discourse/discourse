# frozen_string_literal: true

class PushSubscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :user_auth_token, optional: true

  # Bulk token deletions skip callbacks and can leave orphaned subscriptions.
  scope :with_unexpired_login, -> { where(user_auth_token_id: UserAuthToken.unexpired.select(:id)) }

  def parsed_data
    JSON.parse(data)
  end
end

# == Schema Information
#
# Table name: push_subscriptions
#
#  id                 :bigint           not null, primary key
#  data               :string           not null
#  error_count        :integer          default(0), not null
#  first_error_at     :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_auth_token_id :integer
#  user_id            :integer          not null
#
# Indexes
#
#  index_push_subscriptions_on_user_auth_token_id  (user_auth_token_id) WHERE (user_auth_token_id IS NOT NULL)
#  index_push_subscriptions_on_user_id             (user_id)
#
