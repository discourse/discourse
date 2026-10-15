# frozen_string_literal: true

describe "Composer - ProseMirror - Autocomplete" do
  include_context "with prosemirror editor"

  fab!(:tag)
  fab!(:category_with_emoji) do
    Fabricate(:category, slug: "cat", emoji: "cat", style_type: "emoji")
  end
  fab!(:category_with_icon) { Fabricate(:category, icon: "bell", style_type: "icon") }
  fab!(:category_without_icon, :category)

  it "triggers an autocomplete on mention" do
    open_composer
    composer.type_content("@#{current_user.username}")

    expect(composer).to have_mention_autocomplete
  end

  it "triggers an autocomplete on hashtag" do
    open_composer
    composer.type_content("##{tag.name}")

    expect(composer).to have_hashtag_autocomplete
  end

  it "triggers an autocomplete on emoji" do
    open_composer
    composer.type_content(":smile")

    expect(composer).to have_emoji_autocomplete
  end

  it "keeps emoji autocomplete open when pressing arrow down near a horizontal rule" do
    open_composer

    begin
      browser_page.keyboard.press("Enter")
      browser_page.keyboard.type("---")
      browser_page.keyboard.press("Enter")
    end

    expect(rich.locator("hr").filter(visible: true)).not_to PlaywrightMatchers.have_count(0)

    begin
      browser_page.keyboard.press("ArrowUp")
      browser_page.keyboard.press("ArrowUp")
    end
    composer.type_content(" :smi")

    expect(composer).to have_emoji_autocomplete_selected(1)

    browser_page.keyboard.press("ArrowDown")

    expect(composer).to have_emoji_autocomplete_selected(2)

    browser_page.keyboard.press("ArrowUp")

    expect(composer).to have_emoji_autocomplete_selected(1)
  end

  it "strips partially written emoji when using 'more' emoji modal" do
    open_composer

    composer.type_content("Why :repeat_single")

    expect(composer).to have_emoji_autocomplete

    # "more" emoji picker
    begin
      browser_page.keyboard.press("ArrowDown")
      browser_page.keyboard.press("Enter")
    end
    browser_root.locator("img[data-emoji='repeat_single_button']").filter(visible: true).click
    composer.toggle_rich_editor

    expect(composer).to have_value("Why :repeat_single_button: ")
  end

  context "with composer messages" do
    fab!(:category)

    it "shows a popup" do
      open_composer
      composer.type_content("Maybe @staff can help?")

      expect(composer).to have_popup_content(
        I18n.t("js.composer.cannot_see_group_mention.not_mentionable", group: "staff"),
      )
    end
  end

  describe "mentions" do
    fab!(:topic) { Fabricate(:topic, category: category_with_emoji) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:mixed_case_user) { Fabricate(:user, username: "TestUser_123") }
    fab!(:mixed_case_group) do
      Fabricate(:group, name: "TestGroup_ABC", mentionable_level: Group::ALIAS_LEVELS[:everyone])
    end

    before do
      Draft.set(
        current_user,
        topic.draft_key,
        0,
        { reply: "hey @#{current_user.username} and @unknown - how are you?" }.to_json,
      )
    end

    it "validates manually typed mentions" do
      open_composer

      composer.type_content("Hey @#{current_user.username} ")

      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(current_user.username)],
        useInnerText: true,
      )

      composer.type_content("and @invalid_user - how are you?")

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.mention")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("@invalid_user")],
        useInnerText: true,
      )

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "Hey @#{current_user.username} and @invalid_user - how are you?",
      )
    end

    it "validates mentions in drafts" do
      browser_page.goto("/t/#{topic.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(composer).to be_opened

      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(current_user.username)],
        useInnerText: true,
      )
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.mention")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("@unknown")],
        useInnerText: true,
      )
    end

    it "validates mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testuser_123 and @TESTUSER_123 ")

      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("testuser_123")],
        useInnerText: true,
      )
      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("TESTUSER_123")],
        useInnerText: true,
      )

      composer.type_content("and @InvalidUser ")

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.mention")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("@InvalidUser")],
        useInnerText: true,
      )
    end

    it "validates group mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testgroup_abc and @TESTGROUP_ABC ")

      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("testgroup_abc")],
        useInnerText: true,
      )
      expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
        [browser_text_pattern("TESTGROUP_ABC")],
        useInnerText: true,
      )

      composer.type_content("and @InvalidGroup ")

      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator("a.mention")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.contain_text(
        [browser_text_pattern("@InvalidGroup")],
        useInnerText: true,
      )
    end

    context "with unicode usernames" do
      fab!(:category)

      before do
        SiteSetting.external_system_avatars_enabled = true
        SiteSetting.external_system_avatars_url =
          "/letter_avatar_proxy/v4/letter/{first_letter}/{color}/{size}.png"
        SiteSetting.unicode_usernames = true

        stub_request(:get, %r{\Ahttps://avatars\.discourse-cdn\.com/}).to_return(
          status: 200,
          body: "",
        )
      end

      it "renders unicode mentions as nodes" do
        unicode_user = Fabricate(:unicode_user)

        open_composer

        composer.type_content("Hey @#{unicode_user.username} - how are you?")

        expect(rich.locator("a.mention").filter(visible: true)).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(unicode_user.username)],
          useInnerText: true,
        )

        composer.toggle_rich_editor

        expect(composer).to have_value("Hey @#{unicode_user.username} - how are you?")
      end
    end
  end

  describe "hashtags" do
    it "correctly renders category with emoji hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("here is the ##{category_with_emoji.slug[0..1]}")
      expect(composer).to have_hashtag_autocomplete

      # the xpath here is to get the parent element, which is the actual hashtag-autocomplete__option
      browser_root
        .locator(".hashtag-color--category-#{category_with_emoji.id}")
        .filter(visible: true)
        .locator("xpath=..")
        .click
      expect(
        rich.locator(
          ".hashtag-cooked .hashtag-category-emoji.hashtag-color--category-#{category_with_emoji.id} img.emoji[title='cat']",
        ).filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "correctly renders category with icon hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("here is the ##{category_with_icon.slug[0..1]}")
      expect(composer).to have_hashtag_autocomplete

      browser_root
        .locator(".hashtag-color--category-#{category_with_icon.id}")
        .filter(visible: true)
        .locator("xpath=..")
        .click
      expect(
        rich.locator(
          ".hashtag-cooked .hashtag-category-icon.hashtag-color--category-#{category_with_icon.id} svg.d-icon.d-icon-bell",
        ).filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        rich.locator(".hashtag-cooked svg use[href='#bell']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "correctly renders category with square hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("here is the ##{category_without_icon.slug[0..1]}")
      expect(composer).to have_hashtag_autocomplete

      browser_root
        .locator(".hashtag-color--category-#{category_without_icon.id}")
        .filter(visible: true)
        .locator("xpath=..")
        .click
      expect(
        rich.locator(
          ".hashtag-cooked .hashtag-category-square.hashtag-color--category-#{category_without_icon.id}",
        ).filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "correctly renders tag hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("##{tag.name[0..2]}")
      expect(composer).to have_hashtag_autocomplete

      browser_root
        .locator(".hashtag-color--tag-#{tag.id}")
        .filter(visible: true)
        .locator("xpath=..")
        .click
      expect(
        rich.locator(".hashtag-cooked .d-icon.d-icon-tag.hashtag-color--tag-#{tag.id}").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end
end
