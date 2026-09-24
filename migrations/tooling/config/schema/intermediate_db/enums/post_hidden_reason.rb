# frozen_string_literal: true

Migrations::Tooling::Schema.enum :post_hidden_reason do
  source { ::Post.hidden_reasons }
end
