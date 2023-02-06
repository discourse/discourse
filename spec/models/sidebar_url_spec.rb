# frozen_string_literal: true

RSpec.describe SidebarUrl do
  it "validates path" do
    expect(SidebarUrl.new(icon: "link", name: "categories", value: "/categories").valid?).to eq(
      true,
    )
    expect(SidebarUrl.new(icon: "link", name: "categories", value: "/invalid_path").valid?).to eq(
      false,
    )
  end
end
