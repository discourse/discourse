# frozen_string_literal: true

Fabricator(:search_log) do
  term "ruby"
  search_type SearchLog.search_types[:header]
  ip_address "127.0.0.1"
end
