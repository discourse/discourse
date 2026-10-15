# frozen_string_literal: true

RSpec.describe Migrations::Importer::Step do
  it "exposes the dependency metadata macros via Migrations::StepDependencies" do
    expect(described_class).to be_a(Migrations::StepDependencies)
    expect(described_class).to respond_to(:depends_on, :dependencies, :priority)
  end

  it "provides an empty set when a required set condition is false" do
    conditional_step_class =
      Class.new(described_class) do
        requires_set :values, "invalid SQL", condition: -> { false }

        attr_reader :values
      end
    step =
      conditional_step_class.new(nil, nil, instance_double(Migrations::Importer::SharedData), {})

    step.execute

    expect(step.values).to be_empty
  end
end
