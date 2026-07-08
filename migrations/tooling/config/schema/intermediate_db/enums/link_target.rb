# frozen_string_literal: true

Migrations::Tooling::Schema.enum :link_target do
  value :topic, 1
  value :post, 2
  value :user, 3
  value :category, 4
  value :tag, 5
  value :group, 6
  value :badge, 7
end
