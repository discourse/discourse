# frozen_string_literal: true

describe "Composer", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(user) }

  it "displays user cards in preview" do
    page.visit "/new-topic"

    expect(composer).to be_opened

    composer.fill_content("@#{user.username}")
    composer.preview.find("a.mention").click

    page.has_css?("#user-card")
  end
end
