# frozen_string_literal: true

describe "Composer Preview", type: :system do
  fab!(:user) { Fabricate(:user, username: "bob") }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in user }

  it "correctly updates code blocks in diffhtml preview" do
    SiteSetting.enable_diffhtml_preview = true

    visit("/latest")
    find("#create-topic").click

    expect(composer).to have_composer_input
    composer.fill_content <<~MD
      ```rb
      const = {
        id: t.name,
        text: t.name,
        name: t.name,
      ```
    MD

    within(composer.preview) { expect(find("code.language-ruby")).to have_content("const = {") }

    composer.move_cursor_after("const")
    composer.type_content("ant")

    within(composer.preview) { expect(find("code.language-ruby")).to have_content("constant = {") }
  end

  it "correctly updates mentions in diffhtml preview" do
    SiteSetting.enable_diffhtml_preview = true

    visit("/latest")
    find("#create-topic").click

    expect(composer).to have_composer_input
    composer.fill_content <<~MD
      @bob text
    MD

    within(composer.preview) { expect(page.find("a.mention")).to have_text("@bob") }

    composer.select_all
    composer.type_content("@system")

    within(composer.preview) { expect(page.find("a.mention")).to have_text("@system") }
  end
end
