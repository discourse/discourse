# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Base do
  describe "#steps" do
    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Topics", Class.new(Migrations::Conversion::ProgressStep))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
        end,
      )
    end

    after { Object.send(:remove_const, "TemporaryConverterModule") }

    it "discovers both `Step` and `ProgressStep` subclasses" do
      converter = TemporaryConverterModule::Converter.new(nil)

      expect(converter.steps).to eq(
        [TemporaryConverterModule::Topics, TemporaryConverterModule::Users],
      )
    end
  end
end
