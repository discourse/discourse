# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Converter::Failure do
  let(:failure) { described_class.new([field]) }
  let(:field) { JsonApiKit::Name::Field.new(value: "posted_at", type: "topics") }

  describe "#convert_names" do
    subject(:conversion_failure) { failure.convert_names { it.with(type: "discussions") } }

    it "returns a failure with the translated names" do
      expect(conversion_failure).to have_attributes(names: [field.with(type: "discussions")])
    end

    it "preserves the original failure's names" do
      conversion_failure
      expect(failure.names).to eq([field])
    end

    context "when a name expands into several names" do
      subject(:conversion_failure) { failure.convert_names { previous_names } }

      let(:previous_names) { [field.with(value: "posted_date"), field.with(value: "posted_time")] }

      it "preserves the order of the input fields" do
        expect(conversion_failure.names).to eq(previous_names)
      end

      it "uses the translated names in the message" do
        expect(conversion_failure.message).to eq(
          "cannot convert the value of posted_date, posted_time",
        )
      end
    end
  end
end
