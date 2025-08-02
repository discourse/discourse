# frozen_string_literal: true

RSpec.describe ::Migrations::Converters::Base::Step do
  let(:tracker) { instance_double(::Migrations::Converters::Base::StepTracker) }

  before do
    Object.const_set(
      "TemporaryModule",
      Module.new do
        const_set("TopicUsers", Class.new(::Migrations::Converters::Base::Step) {})
        const_set("Users", Class.new(::Migrations::Converters::Base::Step) {})
      end,
    )
  end

  after do
    TemporaryModule.send(:remove_const, "TopicUsers")
    TemporaryModule.send(:remove_const, "Users")
    Object.send(:remove_const, "TemporaryModule")
  end

  describe ".title" do
    it "uses the classname within title" do
      expect(TemporaryModule::TopicUsers.title).to eq("Converting topic users")
      expect(TemporaryModule::Users.title).to eq("Converting users")
    end

    it "uses the `title` attribute if it has been set" do
      TemporaryModule::Users.title "Foo bar"
      expect(TemporaryModule::Users.title).to eq("Foo bar")
    end
  end

  describe "#initialize" do
    it "works when no arguments are supplied" do
      step = nil
      expect { step = TemporaryModule::Users.new(tracker) }.not_to raise_error
      expect(step.settings).to be_nil
    end

    it "initializes the `settings` attribute if given" do
      settings = { a: 1, b: 2 }
      step = TemporaryModule::Users.new(tracker, settings:)
      expect(step.settings).to eq(settings)
    end

    it "initializes additional attributes if they exist" do
      TemporaryModule::Users.class_eval { attr_accessor :foo, :bar }

      settings = { a: 1, b: 2 }
      foo = "a string"
      bar = false

      step = TemporaryModule::Users.new(tracker, settings:, foo:, bar:, non_existent: 123)
      expect(step.settings).to eq(settings)
      expect(step.foo).to eq(foo)
      expect(step.bar).to eq(bar)
      expect(step).to_not respond_to(:non_existent)
    end
  end
end
