# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::Converter do
  describe "#step_args" do
    it "builds a fresh source adapter per step so concurrent steps don't share a connection" do
      adapters = [
        instance_double(Migrations::Converters::Adapter::Postgres),
        instance_double(Migrations::Converters::Adapter::Postgres),
      ]
      allow(Migrations::Converters::Adapter::Postgres).to receive(:new).and_return(*adapters)

      converter = described_class.new(source_db: { host: "localhost" })

      first = converter.step_args(:first_step)[:source_db]
      second = converter.step_args(:second_step)[:source_db]

      expect(first).to be(adapters[0])
      expect(second).to be(adapters[1])
      expect(Migrations::Converters::Adapter::Postgres).to have_received(:new).with(
        { host: "localhost" },
      ).twice
    end
  end
end
