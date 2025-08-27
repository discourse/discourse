# frozen_string_literal: true

RSpec.describe "RSpec Mocks from_described_class" do
  class TestClass
    def self.clock_time
      Time.now.to_f
    end

    def instance_method
      self.class.clock_time
    end
  end

  module SomeModule
    class OtherClass
      def call_test_class
        TestClass.clock_time
      end
    end
  end

  describe TestClass do
    describe ".clock_time" do
      it "stubs the method when called from described class" do
        allow(TestClass).to receive(:clock_time).from_described_class.and_return(999.0)

        # Call from within TestClass (via instance method)
        instance = described_class.new
        expect(instance.instance_method).to eq(999.0)
      end

      it "does not stub the method when called from another class" do
        allow(TestClass).to receive(:clock_time).from_described_class.and_return(999.0)

        # Call from OtherClass should use real method
        other = SomeModule::OtherClass.new
        result = other.call_test_class
        expect(result).not_to eq(999.0)
        expect(result).to be_a(Float)
      end

      it "allows chaining with other expectations" do
        allow(TestClass).to receive(:clock_time).from_described_class.twice.and_return(1.0, 2.0)

        instance = described_class.new
        expect(instance.instance_method).to eq(1.0)
        expect(instance.instance_method).to eq(2.0)
        expect { instance.instance_method }.to raise_error(RSpec::Mocks::MockExpectationError)
      end
    end
  end

  describe SomeModule::OtherClass do
    it "stubs the method when called from described class" do
      allow(TestClass).to receive(:clock_time).from_described_class.and_return(777.0)

      instance = described_class.new
      result = instance.call_test_class
      expect(result).to eq(777.0)
    end
  end
end
