# frozen_string_literal: true

module DiscourseAutomation
  module Statistics
    extend PeriodCountHelper

    def self.total
      { count: Automation.count }
    end

    def self.created
      period_counts(Automation.all, :created_at, count: false)
    end

    def self.edited
      period_counts(Automation.where("updated_at > created_at"), :updated_at, count: false)
    end

    def self.executed
      period_counts(DiscourseAutomation::Stat.all, :date, count: false) do |scope|
        scope.distinct.count(:automation_id)
      end
    end

    def self.executions
      period_counts(DiscourseAutomation::Stat.all, :date) { |scope| scope.sum(:total_runs) }
    end
  end
end
