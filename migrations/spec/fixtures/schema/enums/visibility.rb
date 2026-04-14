# frozen_string_literal: true

Migrations::Database::Schema.enum :visibility do
  value :public, 0
  value :private, 1
  value :restricted, 2
end
