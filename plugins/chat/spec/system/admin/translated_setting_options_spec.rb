# frozen_string_literal: true

RSpec.describe "Translated Chat setting options" do
  fab!(:admin)

  it "shows translated options and defaults for the preferred index and archive status" do
    sign_in(admin)
    visit("/admin/plugins/chat/settings")

    expect(page).to have_select(
      "Chat preferred index",
      options: ["Channels", "Direct messages", "My threads"],
      selected: "Channels",
    )
    expect(page).to have_select(
      "Chat archive destination topic status",
      options: %w[Archived Open Closed],
      selected: "Archived",
    )
  end
end
