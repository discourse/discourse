# frozen_string_literal: true

Fabricator(:search_log) do
  term "ruby"
  search_type SearchLog.search_types[:header]
  ip_address "127.0.0.1"
end

Fabricator(:clicked_search_log, from: :search_log) do
  search_result_id 1
  search_result_type SearchLog.search_result_types[:topic]
end
