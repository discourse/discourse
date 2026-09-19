# frozen_string_literal: true

Migrations::Tooling::Schema.enum :hashtag_type do
  value :category, 1
  value :tag, 2
end
