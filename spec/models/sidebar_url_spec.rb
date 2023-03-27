# frozen_string_literal: true

RSpec.describe SidebarUrl do
  it "validates path" do
    expect(SidebarUrl.new(icon: "link", name: "categories", value: "/categories").valid?).to eq(
      true,
    )
    expect(SidebarUrl.new(icon: "link", name: "categories", value: "/invalid_path").valid?).to eq(
      false,
    )
    expect(
      SidebarUrl.new(
        icon: "link",
        name: "external",
        value: "https://www.test.com/discourse-test",
      ).valid?,
    ).to eq(true)
  end

  it "sets external flag" do
    expect(
      SidebarUrl.create!(icon: "link", name: "categories", value: "/categories").external,
    ).to be false
    expect(
      SidebarUrl.create!(
        icon: "link",
        name: "categories",
        value: "http://#{Discourse.current_hostname}/categories",
      ).external,
    ).to be false
    expect(
      SidebarUrl.create!(
        icon: "link",
        name: "categories",
        value: "https://#{Discourse.current_hostname}/categories",
      ).external,
    ).to be false
    expect(
      SidebarUrl.create!(
        icon: "link",
        name: "categories",
        value: "https://www.test.com/discourse-test",
      ).external,
    ).to be true
  end
end
