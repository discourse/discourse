# frozen_string_literal: true

class SearchLogsSerializer < ApplicationSerializer
  root 'search_logs'

  attributes :term,
             :searches,
             :ctr
end
