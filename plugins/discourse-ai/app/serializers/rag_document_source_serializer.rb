# frozen_string_literal: true

class RagDocumentSourceSerializer < ApplicationSerializer
  attributes :id,
             :url,
             :refresh_interval_hours,
             :last_fetched_at,
             :next_refresh_at,
             :last_error_at,
             :last_error
end
