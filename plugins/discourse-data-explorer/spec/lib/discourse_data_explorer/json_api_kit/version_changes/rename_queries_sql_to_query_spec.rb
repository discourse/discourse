# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionChanges::RenameQueriesSqlToQuery do
  it "is dated 2026-06-15 with a client-facing description" do
    expect(described_class.version.to_s).to eq("2026-06-15")
    expect(described_class.description).to include("renamed to `query`")
  end

  it "down-migrates a queries resource back to the old shape" do
    resource = { type: :queries, attributes: { name: "Top", query: "SELECT 1" } }

    described_class.transform_for(:down, type: "queries").call(resource)

    expect(resource[:attributes]).to eq(name: "Top", sql: "SELECT 1")
  end

  it "up-migrates an old queries resource to the latest shape" do
    resource = { type: :queries, attributes: { name: "Top", sql: "SELECT 1" } }

    described_class.transform_for(:up, type: "queries").call(resource)

    expect(resource[:attributes]).to eq(name: "Top", query: "SELECT 1")
  end
end
