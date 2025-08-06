# frozen_string_literal: true

module DiscourseAssign
  module PostExtension
    extend ActiveSupport::Concern

    prepended { has_one :assignment, as: :target, dependent: :destroy }
  end
end
