# frozen_string_literal: true

module NestedReplies
  module StatsFreshness
    def self.valid_after
      SiteSetting.nested_replies_stats_valid_after.to_f
    end

    def self.current?(timestamp)
      timestamp.present? && timestamp.to_f >= valid_after
    end

    def self.stale_sql(column)
      cutoff = valid_after
      conditions = ["#{column} IS NULL"]
      conditions << "#{column} < TO_TIMESTAMP(#{cutoff})" if cutoff.positive?
      conditions.join(" OR ")
    end
  end
end
