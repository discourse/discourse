# frozen_string_literal: true

Migrations::Tooling::Schema.enum :mention_type do
  value :user, 1
  value :group, 2
  value :here, 3
  value :all, 4
end
