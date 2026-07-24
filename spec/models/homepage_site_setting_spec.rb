# frozen_string_literal: true

describe HomepageSiteSetting do
  it "offers the top_menu fallback and every homepage choice" do
    values = described_class.values

    expect(values.first).to eq({ name: "admin.homepage.top_menu_default", value: "" })
    expect(values.map { |v| v[:value] }).to include(*TopMenu.choices)
    expect(described_class.translate_names?).to eq(true)
  end

  it "includes filters registered at runtime" do
    filters = Discourse.filters
    Discourse.stubs(:filters).returns(filters + [:custom_filter])

    expect(described_class.values).to include(
      { name: "filters.custom_filter.title", value: "custom_filter" },
    )
  end

  it "does not offer unread when it is excluded from top menu choices" do
    TopMenu.stubs(:choices).returns(%w[latest new top categories])

    expect(described_class.values.map { |v| v[:value] }).not_to include("unread")
  end

  it "validates values" do
    expect(described_class.valid_value?("")).to eq(true)
    expect(described_class.valid_value?("latest")).to eq(true)
    expect(described_class.valid_value?("invalid")).to eq(false)
  end
end
