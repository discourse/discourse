# frozen_string_literal: true

RSpec.describe Migrations::Importer::Step do
  it "exposes the dependency metadata macros via Migrations::StepDependencies" do
    expect(described_class).to be_a(Migrations::StepDependencies)
    expect(described_class).to respond_to(:depends_on, :dependencies, :priority)
  end
end
