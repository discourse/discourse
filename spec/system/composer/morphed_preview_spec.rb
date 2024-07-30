# frozen_string_literal: true

describe "Morphed Composer Preview", type: :system do
  fab!(:user) { Fabricate(:user, username: "bob", refresh_auto_groups: true) }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.enable_diffhtml_preview = true
    sign_in user
    visit("/new-topic")
  end

  it "correctly morphs code blocks" do
    composer.fill_content <<~MD
      ```js
      const = {
        id: t.name,
        text: t.name,
        name: t.name,
      ```
    MD

    within(composer.preview) { expect(find("code.lang-js")).to have_text("const = {") }

    composer.move_cursor_after("const")
    composer.type_content("ant")

    within(composer.preview) { expect(find("code.lang-js")).to have_text("constant = {") }
  end

  it "correctly morphs mentions" do
    composer.fill_content("@bob text")

    within(composer.preview) { expect(find("a.mention")).to have_text("@bob") }

    composer.select_all
    composer.type_content("@system")

    within(composer.preview) { expect(find("a.mention")).to have_text("@system") }
  end
end
