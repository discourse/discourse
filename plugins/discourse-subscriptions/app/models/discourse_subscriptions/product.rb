# frozen_string_literal: true

module DiscourseSubscriptions
  class Product < ActiveRecord::Base
  end
end

# == Schema Information
#
# Table name: discourse_subscriptions_products
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  external_id :string           not null
#
# Indexes
#
#  index_discourse_subscriptions_products_on_external_id  (external_id)
#
