# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::ParameterName do
  subject(:parameter_name) { described_class.new("page", "anchor") }

  describe "#to_s" do
    it "writes the members in brackets after the family" do
      expect(parameter_name.to_s).to eq("page[anchor]")
    end

    context "when the name has one part" do
      subject(:parameter_name) { described_class.new("sort") }

      it "writes the family alone" do
        expect(parameter_name.to_s).to eq("sort")
      end
    end
  end

  describe "#family" do
    it "returns the name without its members" do
      expect(parameter_name.family.to_s).to eq("page")
    end
  end

  describe "#member" do
    it "returns the name one member deeper" do
      expect(parameter_name.member("createdAt").to_s).to eq("page[anchor][createdAt]")
    end
  end
end
