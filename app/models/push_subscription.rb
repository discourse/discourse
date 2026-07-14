# frozen_string_literal: true

class PushSubscription < ActiveRecord::Base
  belongs_to :user

  def parsed_data
    JSON.parse(data)
  end
end

# == Schema Information
#
# Table name: push_subscriptions
#
#  id             :bigint           not null, primary key
#  data           :string           not null
#  error_count    :integer          default(0), not null
#  first_error_at :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer          not null
#
