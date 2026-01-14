# frozen_string_literal: true

module DiscourseSubscriptions
  class Subscription < ActiveRecord::Base
    belongs_to :customer
  end
end

# == Schema Information
#
# Table name: discourse_subscriptions_subscriptions
#
#  id          :bigint           not null, primary key
#  customer_id :bigint           not null
#  external_id :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  status      :string
#
# Indexes
#
#  index_discourse_subscriptions_subscriptions_on_customer_id  (customer_id)
#  index_discourse_subscriptions_subscriptions_on_external_id  (external_id)
#
