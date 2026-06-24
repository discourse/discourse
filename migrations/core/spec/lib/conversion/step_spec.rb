# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Step do
  before do
    Object.const_set(
      "TemporaryModule",
      Module.new do
        const_set("TopicUsers", Class.new(Migrations::Conversion::Step) {})
        const_set("Users", Class.new(Migrations::Conversion::Step) {})
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
      expect { step = TemporaryModule::Users.new }.not_to raise_error
      expect(step.settings).to be_nil
    end

    it "creates its own tracker" do
      step = TemporaryModule::Users.new
      expect(step.tracker).to be_a(Migrations::Conversion::StepTracker)
      expect(step.tracker).not_to be(TemporaryModule::Users.new.tracker)
    end

    it "initializes the `settings` attribute if given" do
      settings = { a: 1, b: 2 }
      step = TemporaryModule::Users.new(settings:)
      expect(step.settings).to eq(settings)
    end

    it "initializes additional attributes if they exist" do
      TemporaryModule::Users.class_eval { attr_accessor :foo, :bar }

      settings = { a: 1, b: 2 }
      foo = "a string"
      bar = false

      step = TemporaryModule::Users.new(settings:, foo:, bar:, non_existent: 123)
      expect(step.settings).to eq(settings)
      expect(step.foo).to eq(foo)
      expect(step.bar).to eq(bar)
      expect(step).to_not respond_to(:non_existent)
    end

    it "skips attributes with a private setter" do
      TemporaryModule::Users.class_eval do
        attr_writer :secret
        private :secret=
      end

      step = nil
      expect { step = TemporaryModule::Users.new(secret: 123) }.not_to raise_error
      expect(step.instance_variable_defined?(:@secret)).to be(false)
    end
  end
end
