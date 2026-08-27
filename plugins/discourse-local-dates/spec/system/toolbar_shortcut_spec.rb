# frozen_string_literal: true

RSpec.describe "Local dates toolbar shortcut" do
  fab!(:current_user, :admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(current_user) }

  it "shows the shortcut without hovering the menu row" do
    visit "/"
    find("#create-topic").click
    expect(composer).to be_opened

    find(".toolbar-menu__options-trigger").click

    expect(page).to have_css(
      ".toolbar-menu__options-content [data-name='local-dates'] .d-shortcut",
      visible: :visible,
    )
  end
end
