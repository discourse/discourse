# frozen_string_literal: true

Migrations::Tooling::Schema.enum :link_target do
  value :topic, 1
  value :post, 2
end
