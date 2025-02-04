# frozen_string_literal: true

describe "Composer - ProseMirror editor", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tag)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }

  before do
    sign_in(user)
    SiteSetting.rich_editor = true
  end

  it "hides the Composer container's preview button" do
    page.visit "/new-topic"

    expect(composer).to be_opened
    expect(composer).to have_composer_preview_toggle

    composer.toggle_rich_editor

    expect(composer).to have_no_composer_preview_toggle
  end

  context "with autocomplete" do
    it "triggers an autocomplete on mention" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor

      composer.type_content("@#{user.username}")

      expect(composer).to have_mention_autocomplete
    end

    it "triggers an autocomplete on hashtag" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      find(".composer-toggle-switch").click
      composer.type_content("##{tag.name}")

      expect(composer).to have_hashtag_autocomplete
    end

    it "triggers an autocomplete on emoji" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content(":smile")

      expect(composer).to have_emoji_autocomplete
    end
  end

  context "with inputRules" do
    it "supports > to create a blockquote" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("> This is a blockquote")

      expect(rich).to have_css("blockquote", text: "This is a blockquote")
    end

    it "supports n. to create an ordered list" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("1. Item 1\n5. Item 2")

      expect(rich).to have_css("ol li", text: "Item 1")
      expect(find("ol ol", text: "Item 2")["start"]).to eq("5")
    end

    it "supports *, - or + to create an unordered list" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("* Item 1\n")
      composer.type_content("- Item 2\n")
      composer.type_content("+ Item 3")

      expect(rich).to have_css("ul ul li", count: 3)
    end

    it "supports ``` or 4 spaces to create a code block" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("```\nThis is a code block")
      composer.send_keys(%i[shift enter])
      composer.type_content("    This is a code block")

      expect(rich).to have_css("pre code", text: "This is a code block", count: 2)
    end

    it "supports 1-6 #s to create a heading" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("# Heading 1\n")
      composer.type_content("## Heading 2\n")
      composer.type_content("### Heading 3\n")
      composer.type_content("#### Heading 4\n")
      composer.type_content("##### Heading 5\n")
      composer.type_content("###### Heading 6\n")

      expect(rich).to have_css("h1", text: "Heading 1")
      expect(rich).to have_css("h2", text: "Heading 2")
      expect(rich).to have_css("h3", text: "Heading 3")
      expect(rich).to have_css("h4", text: "Heading 4")
      expect(rich).to have_css("h5", text: "Heading 5")
      expect(rich).to have_css("h6", text: "Heading 6")
    end

    it "supports _ or * to create an italic text" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("_This is italic_\n")
      composer.type_content("*This is italic*")

      expect(rich).to have_css("em", text: "This is italic", count: 2)
    end

    it "supports __ or ** to create a bold text" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("__This is bold__\n")
      composer.type_content("**This is bold**")

      expect(rich).to have_css("strong", text: "This is bold", count: 2)
    end

    it "supports ` to create a code text" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("`This is code`")

      expect(rich).to have_css("code", text: "This is code")
    end
  end

  context "with keymap" do
    PLATFORM_KEY_MODIFIER = SystemHelpers::PLATFORM_KEY_MODIFIER
    it "supports Ctrl + B to create a bold text" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content([PLATFORM_KEY_MODIFIER, "b"])
      composer.type_content("This is bold")

      expect(rich).to have_css("strong", text: "This is bold")
    end

    it "supports Ctrl + I to create an italic text" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content([PLATFORM_KEY_MODIFIER, "i"])
      composer.type_content("This is italic")

      expect(rich).to have_css("em", text: "This is italic")
    end

    xit "supports Ctrl + K to create a link" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      page.send_keys([PLATFORM_KEY_MODIFIER, "k"])
      page.send_keys("https://www.example.com\t")
      page.send_keys("This is a link")
      page.send_keys(:enter)

      expect(rich).to have_css("a", text: "This is a link")
    end

    it "supports Ctrl + Shift + 7 to create an ordered list" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("Item 1")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "7"])

      expect(rich).to have_css("ol li", text: "Item 1")
    end

    it "supports Ctrl + Shift + 8 to create a bullet list" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("Item 1")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "8"])

      expect(rich).to have_css("ul li", text: "Item 1")
    end

    it "supports Ctrl + Shift + 9 to create a blockquote" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("This is a blockquote")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "9"])

      expect(rich).to have_css("blockquote", text: "This is a blockquote")
    end

    it "supports Ctrl + Shift + 1-6 for headings, 0 for reset" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor

      (1..6).each do |i|
        composer.type_content("\nHeading #{i}")
        composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, i.to_s])

        expect(rich).to have_css("h#{i}", text: "Heading #{i}")
      end

      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "0"])
      expect(rich).not_to have_css("h6")
    end

    it "supports Ctrl + Z and Ctrl + Shift + Z to undo and redo" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("This is a test")
      composer.send_keys([PLATFORM_KEY_MODIFIER, "z"])

      expect(rich).not_to have_css("p", text: "This is a test")

      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "z"])

      expect(rich).to have_css("p", text: "This is a test")
    end

    it "supports Ctrl + Shift + _ to create a horizontal rule" do
      page.visit "/new-topic"

      expect(composer).to be_opened

      composer.toggle_rich_editor
      composer.type_content("This is a test")
      composer.send_keys([PLATFORM_KEY_MODIFIER, :shift, "_"])

      expect(rich).to have_css("hr")
    end
  end
end
