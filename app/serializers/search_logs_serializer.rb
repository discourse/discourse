class SearchLogsSerializer < ApplicationSerializer
  attributes :term,
             :searches,
             :ctr
end
