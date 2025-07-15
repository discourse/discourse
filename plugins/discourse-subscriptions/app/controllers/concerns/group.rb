# frozen_string_literal: true

module DiscourseSubscriptions
  module Group
    extend ActiveSupport::Concern

    def plan_group(plan)
      ::Group.find_by_name(plan[:metadata][:group_name])
    end
  end
end
