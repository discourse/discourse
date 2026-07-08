# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionChanges::RenameQueriesSqlToQuery do
  it "is dated 2026-06-15" do
    expect(described_class.version.to_s).to eq("2026-06-15")
  end

  it "carries a client-facing description" do
    expect(described_class.description).to include("renamed to `query`")
  end

  describe "the down transform" do
    subject(:down) { described_class.transform_for(:down, type: "queries") }

    context "when the resource carries the renamed attribute" do
      let(:resource) { { type: :queries, attributes: { name: "Top", query: "SELECT 1" } } }

      before { down.call(resource) }

      it "renames query back to sql" do
        expect(resource[:attributes]).to eq(name: "Top", sql: "SELECT 1")
      end
    end

    context "when a sparse fieldset excluded the attribute" do
      let(:resource) { { type: :queries, attributes: { name: "Top" } } }

      before { down.call(resource) }

      it "leaves the resource untouched" do
        expect(resource[:attributes]).to eq(name: "Top")
      end
    end
  end

  describe "the up transform" do
    subject(:up) { described_class.transform_for(:up, type: "queries") }

    context "when the resource carries the old attribute" do
      let(:resource) { { type: :queries, attributes: { name: "Top", sql: "SELECT 1" } } }

      before { up.call(resource) }

      it "renames sql to query" do
        expect(resource[:attributes]).to eq(name: "Top", query: "SELECT 1")
      end
    end

    context "when the client did not send the attribute" do
      let(:resource) { { type: :queries, attributes: { name: "Top" } } }

      before { up.call(resource) }

      it "leaves the resource untouched" do
        expect(resource[:attributes]).to eq(name: "Top")
      end
    end
  end
end
