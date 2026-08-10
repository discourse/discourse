# frozen_string_literal: true

require Rails.root.join("db/migrate/20260805183535_add_target_created_by_index_to_reviewables.rb")

RSpec.describe AddTargetCreatedByIndexToReviewables do
  self.use_transactional_tests = false

  subject(:migrate) { described_class.new.migrate(:up) }

  before do
    ActiveRecord::Base.connection.remove_index(
      :reviewables,
      name: "idx_reviewables_flagged_by_target_created_by",
      if_exists: true,
    )
    ActiveRecord::Base.connection.remove_index(
      :reviewables,
      name: "index_reviewables_on_target_created_by_id",
      if_exists: true,
    )
  end

  after { described_class.new.migrate(:down) }

  it "creates an all-type index for the staff-info reviewable counters" do
    migrate

    index =
      ActiveRecord::Base
        .connection
        .indexes(:reviewables)
        .find do |reviewable_index|
          reviewable_index.name == "index_reviewables_on_target_created_by_id"
        end

    expect(index).to have_attributes(columns: ["target_created_by_id"], where: nil)
  end
end
