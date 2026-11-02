# frozen_string_literal: true

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions
Migrations::Database::IntermediateDB.constants.sort.each do |constant_name|
  entity = Migrations::Database::IntermediateDB.const_get(constant_name)
  next unless entity.is_a?(Module)
  next if entity == Migrations::Database::IntermediateDB::Enums

  RSpec.describe entity do
    it_behaves_like "a database entity"
  end
end
# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
