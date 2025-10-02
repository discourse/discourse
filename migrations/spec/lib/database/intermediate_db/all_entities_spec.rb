# frozen_string_literal: true

Migrations::Database::IntermediateDB.constants.each do |const|
  mod = Migrations::Database::IntermediateDB.const_get(const)
  next unless mod.is_a?(Module)
  next if mod == Migrations::Database::IntermediateDB::Enums

  RSpec.describe mod do
    it_behaves_like "a database entity"
  end
end
