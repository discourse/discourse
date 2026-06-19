# frozen_string_literal: true

RSpec.describe DiscourseWireframe::BlockLayoutDraft do
  fab!(:user)
  fab!(:theme)

  it "validates presence of outlet and data and the outlet format" do
    expect(described_class.new(user:, theme:, outlet: "homepage-blocks", data: "{}")).to be_valid
    expect(described_class.new(user:, theme:, outlet: "", data: "{}")).not_to be_valid
    expect(described_class.new(user:, theme:, outlet: "Bad Name!", data: "{}")).not_to be_valid
    expect(described_class.new(user:, theme:, outlet: "homepage-blocks", data: "")).not_to be_valid
  end

  it "accepts a namespaced outlet name" do
    expect(described_class.new(user:, theme:, outlet: "chat:thread-blocks", data: "{}")).to be_valid
  end

  it "caps data at MAX_DATA_BYTES" do
    expect(
      described_class.new(
        user:,
        theme:,
        outlet: "homepage-blocks",
        data: "x" * (described_class::MAX_DATA_BYTES + 1),
      ),
    ).not_to be_valid
  end

  it "enforces uniqueness per (user, theme, outlet) at the database" do
    described_class.create!(user:, theme:, outlet: "homepage-blocks", data: "{}")

    expect {
      described_class.create!(user:, theme:, outlet: "homepage-blocks", data: "{}")
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
