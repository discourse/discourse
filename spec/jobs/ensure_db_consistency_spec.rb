# frozen_string_literal: true

RSpec.describe Jobs::EnsureDbConsistency do
  subject(:job) { described_class.new }

  it "is able to complete with no errors" do
    job.execute({})
  end
end
