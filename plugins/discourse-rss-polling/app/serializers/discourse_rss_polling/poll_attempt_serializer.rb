# frozen_string_literal: true

module DiscourseRssPolling
  class PollAttemptSerializer < ApplicationSerializer
    attributes :id,
               :status,
               :imported_count,
               :updated_count,
               :skipped_count,
               :failed_count,
               :error,
               :items,
               :created_at
  end
end
