# frozen_string_literal: true

module DiscoursePolicy
  module PostExtension
    extend ActiveSupport::Concern

    prepended { has_one :post_policy, dependent: :destroy }
  end
end
