# frozen_string_literal: true

RSpec.describe JsonApiKit::Resource::IdentifierType do
  subject(:identifier_type) { described_class.new(key_type) }

  describe "#cast" do
    context "when the key is an integer" do
      let(:key_type) { ActiveModel::Type.lookup(:integer) }

      it "casts a string of digits" do
        expect(identifier_type.cast("15")).to eq(15)
      end

      it "casts a negative identifier" do
        expect(identifier_type.cast("-15")).to eq(-15)
      end

      it "keeps an integer" do
        expect(identifier_type.cast(15)).to eq(15)
      end

      it "refuses a string without digits" do
        expect(identifier_type.cast("abc")).to be_nil
      end

      it "refuses trailing characters" do
        expect(identifier_type.cast("15abc")).to be_nil
      end

      it "refuses surrounding spaces" do
        expect(identifier_type.cast(" 15 ")).to be_nil
      end

      it "refuses a leading zero" do
        expect(identifier_type.cast("015")).to be_nil
      end
    end

    context "when the key is a UUID" do
      let(:key_type) { ActiveRecord::Type.lookup(:uuid, adapter: :postgresql) }
      let(:uuid) { "1d21ece8-c46f-432b-a501-cd975a50bfb1" }

      it "casts an uppercase UUID to lowercase" do
        expect(identifier_type.cast(uuid.upcase)).to eq(uuid)
      end

      it "refuses a malformed UUID" do
        expect(identifier_type.cast("#{uuid}-abc")).to be_nil
      end
    end

    context "when the key is a string" do
      let(:key_type) { ActiveModel::Type.lookup(:string) }

      it "keeps an opaque identifier" do
        expect(identifier_type.cast("0012")).to eq("0012")
      end
    end
  end
end
