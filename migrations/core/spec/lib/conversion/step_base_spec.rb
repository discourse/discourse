# frozen_string_literal: true

RSpec.describe Migrations::Conversion::StepBase do
  before do
    Object.const_set(
      "TemporaryStepsModule",
      Module.new do
        const_set("Topics", Class.new(Migrations::Conversion::ProgressStep))
        const_set("TopicUsers", Class.new(Migrations::Conversion::Step))
        const_set("Users", Class.new(Migrations::Conversion::Step))
      end,
    )
  end

  after { Object.send(:remove_const, "TemporaryStepsModule") }

  describe "dependency metadata" do
    it "exposes the StepDependencies macros at class level" do
      expect(described_class).to be_a(Migrations::StepDependencies)
      expect(described_class).to respond_to(:depends_on, :dependencies, :priority)
    end

    it "lets steps depend on both `Step` and `ProgressStep` subclasses" do
      TemporaryStepsModule::TopicUsers.depends_on(:topics, :users)

      expect(TemporaryStepsModule::TopicUsers.dependencies).to eq(
        [TemporaryStepsModule::Topics, TemporaryStepsModule::Users],
      )
    end

    it "doesn't bleed metadata between sibling step classes" do
      TemporaryStepsModule::TopicUsers.depends_on(:users)
      TemporaryStepsModule::TopicUsers.priority 1

      expect(TemporaryStepsModule::Users.dependencies).to eq([])
      expect(TemporaryStepsModule::Users.priority).to be_nil
    end
  end
end
