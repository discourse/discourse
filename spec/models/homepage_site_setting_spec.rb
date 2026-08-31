# frozen_string_literal: true

describe HomepageSiteSetting do
  around do |example|
    registrations = DiscoursePluginRegistry._raw_homepage_options.dup
    example.run
    DiscoursePluginRegistry._raw_homepage_options.replace(registrations)
  end

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

  it "includes homepages registered by enabled plugins" do
    plugin = Plugin::Instance.new
    plugin.stubs(:enabled?).returns(true)
    plugin.register_homepage(
      "directory",
      name: "discourse_directory.navigation.title",
      path: "/directory",
      route: "discourse_directory/directory#index",
      anonymous: true,
    )

    expect(described_class.values).to include(
      { name: "discourse_directory.navigation.title", value: "directory" },
    )

    plugin.stubs(:enabled?).returns(false)
    expect(described_class.values.map { |value| value[:value] }).not_to include("directory")
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
