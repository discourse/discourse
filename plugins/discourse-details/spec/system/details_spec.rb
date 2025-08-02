# frozen_string_literal: true

describe "Details button", type: :system do
  fab!(:admin)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  context "with rich editor" do
    before do
      SiteSetting.rich_editor = true
      sign_in(admin)
    end

    it "uses the text selection for content" do
      visit("/new-topic")
      composer.fill_content("test :+1:").toggle_rich_editor.select_all
      find(".toolbar-menu__options-trigger").click
      find("button[title='Hide Details']").click
      rich.click(x: 22, y: 30) # hack for pseudo element

      expect(rich).to have_css(
        "details img.emoji[src=\"/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}\"]",
      )
    end
  end
end
