# frozen_string_literal: true

Migrations::Tooling::Schema.enum :embed_owner do
  value :post, 1
  value :user, 2
end
