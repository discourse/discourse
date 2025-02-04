# frozen_string_literal: true

Fabricator(:admin_notice) do
  priority { "low" }
  identifier { "test_notice" }
  subject { "problem" }
end
