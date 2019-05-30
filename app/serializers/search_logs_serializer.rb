# frozen_string_literal: true

class SearchLogsSerializer < ApplicationSerializer
  attributes :term,
             :searches,
             :ctr
end
