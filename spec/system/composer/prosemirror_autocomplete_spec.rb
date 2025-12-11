# frozen_string_literal: true

describe "Composer - ProseMirror - Autocomplete", type: :system do
  include_context "with prosemirror editor"

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

  it "strips partially written emoji when using 'more' emoji modal" do
    open_composer

    composer.type_content("Why :repeat_single")

    expect(composer).to have_emoji_autocomplete

    # "more" emoji picker
    composer.send_keys(:down, :enter)
    find("img[data-emoji='repeat_single_button']").click
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

      expect(rich).to have_css("a.mention", text: current_user.username)

      composer.type_content("and @invalid_user - how are you?")

      expect(rich).to have_no_css("a.mention", text: "@invalid_user")

      composer.toggle_rich_editor

      expect(composer).to have_value(
        "Hey @#{current_user.username} and @invalid_user - how are you?",
      )
    end

    it "validates mentions in drafts" do
      page.visit("/t/#{topic.id}")

      expect(composer).to be_opened

      expect(rich).to have_css("a.mention", text: current_user.username)
      expect(rich).to have_no_css("a.mention", text: "@unknown")
    end

    it "validates mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testuser_123 and @TESTUSER_123 ")

      expect(rich).to have_css("a.mention", text: "testuser_123")
      expect(rich).to have_css("a.mention", text: "TESTUSER_123")

      composer.type_content("and @InvalidUser ")

      expect(rich).to have_no_css("a.mention", text: "@InvalidUser")
    end

    it "validates group mentions case-insensitively" do
      open_composer

      composer.type_content("Hey @testgroup_abc and @TESTGROUP_ABC ")

      expect(rich).to have_css("a.mention", text: "testgroup_abc")
      expect(rich).to have_css("a.mention", text: "TESTGROUP_ABC")

      composer.type_content("and @InvalidGroup ")

      expect(rich).to have_no_css("a.mention", text: "@InvalidGroup")
    end

    context "with unicode usernames" do
      fab!(:category)

      before do
        SiteSetting.external_system_avatars_enabled = true
        SiteSetting.external_system_avatars_url =
          "/letter_avatar_proxy/v4/letter/{first_letter}/{color}/{size}.png"
        SiteSetting.unicode_usernames = true
      end

      it "renders unicode mentions as nodes" do
        unicode_user = Fabricate(:unicode_user)

        open_composer

        composer.type_content("Hey @#{unicode_user.username} - how are you?")

        expect(rich).to have_css("a.mention", text: unicode_user.username)

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
      find(".hashtag-color--category-#{category_with_emoji.id}").find(:xpath, "..").click
      expect(rich).to have_css(
        ".hashtag-cooked .hashtag-category-emoji.hashtag-color--category-#{category_with_emoji.id} img.emoji[title='cat']",
      )
    end

    it "correctly renders category with icon hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("here is the ##{category_with_icon.slug[0..1]}")
      expect(composer).to have_hashtag_autocomplete

      find(".hashtag-color--category-#{category_with_icon.id}").find(:xpath, "..").click
      expect(rich).to have_css(
        ".hashtag-cooked .hashtag-category-icon.hashtag-color--category-#{category_with_icon.id} svg.d-icon.d-icon-bell",
      )
      expect(rich).to have_css(".hashtag-cooked svg use[href='#bell']")
    end

    it "correctly renders category with square hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("here is the ##{category_without_icon.slug[0..1]}")
      expect(composer).to have_hashtag_autocomplete

      find(".hashtag-color--category-#{category_without_icon.id}").find(:xpath, "..").click
      expect(rich).to have_css(
        ".hashtag-cooked .hashtag-category-square.hashtag-color--category-#{category_without_icon.id}",
      )
    end

    it "correctly renders tag hashtags after selecting from autocomplete" do
      open_composer

      composer.type_content("##{tag.name[0..2]}")
      expect(composer).to have_hashtag_autocomplete

      find(".hashtag-color--tag-#{tag.id}").find(:xpath, "..").click
      expect(rich).to have_css(".hashtag-cooked .d-icon.d-icon-tag.hashtag-color--tag-#{tag.id}")
    end
  end
end
