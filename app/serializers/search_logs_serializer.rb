class SearchLogsSerializer < ApplicationSerializer
  attributes :term,
             :searches,
             :click_through,
             :unique_searches
end
