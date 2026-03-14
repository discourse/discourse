# frozen_string_literal: true

Fabricator(:boost, class_name: "DiscourseBoosts::Boost") do
  post
  user
  raw "🎉"
  cooked { |attrs| DiscourseBoosts::Boost.cook(attrs[:raw] || "🎉") }
end
