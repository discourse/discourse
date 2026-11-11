# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module CustomFieldNames
      OPTIONS_LIMIT = 100

      def self.load_options(scope, filter)
        scope = scope.where.not(name: [nil, ""])
        if filter.present?
          scope = scope.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%")
        end

        scope
          .distinct
          .order(:name)
          .limit(OPTIONS_LIMIT)
          .pluck(:name)
          .map { |name| { id: name, name: name } }
      end
    end
  end
end
