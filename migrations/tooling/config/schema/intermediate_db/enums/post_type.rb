# frozen_string_literal: true

Migrations::Tooling::Schema.enum :post_type do
  source { ::Post.types }
end
