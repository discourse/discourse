# frozen_string_literal: true

module DiscourseSubscriptions
  class Customer < ActiveRecord::Base
    self.table_name = "discourse_subscriptions_customers"

    scope :find_user, ->(user) { find_by_user_id(user.id) }

    has_many :subscriptions

    def self.create_customer(user, customer)
      create(customer_id: customer[:id], user_id: user.id)
    end
  end
end

# == Schema Information
#
# Table name: discourse_subscriptions_customers
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :string           not null
#  product_id  :string
#  user_id     :bigint
#
# Indexes
#
#  index_discourse_subscriptions_customers_on_customer_id  (customer_id)
#  index_discourse_subscriptions_customers_on_user_id      (user_id)
#
