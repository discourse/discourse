# frozen_string_literal: true

describe "Content Localization" do
  TOGGLE_LOCALIZE_BUTTON_SELECTOR = "button.btn-toggle-localized-content"

  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }
  fab!(:site_local_user) { Fabricate(:user, locale: "en") }
  fab!(:admin)

  fab!(:jap_group) { Fabricate(:group).tap { |g| g.add(japanese_user) } }

  fab!(:topic) do
    Fabricate(:topic, title: "Life strategies from The Art of War", locale: "en", user: admin)
  end
  fab!(:post_1) do
    Fabricate(
      :post,
      topic:,
      locale: "en",
      raw: "The masterpiece isn’t just about military strategy",
    )
  end
  fab!(:post_2) do
    Fabricate(
      :post,
      topic:,
      locale: "en",
      raw: "The greatest victory is that which requires no battle",
    )
  end
  fab!(:post_3) { Fabricate(:post, topic:, locale: "ja", raw: "将とは、智・信・仁・勇・厳なり。") }
  fab!(:topic_ja_localization) do
    Fabricate(:topic_localization, topic:, locale: "ja", fancy_title: "孫子兵法からの人生戦略")
  end

  # page objects
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:translation_composer) { PageObjects::Components::TranslationComposer.new }
  let(:post_1_obj) { PageObjects::Components::Post.new(1) }
  let(:post_3_obj) { PageObjects::Components::Post.new(3) }
  let(:post_4_obj) { PageObjects::Components::Post.new(4) }

  def scroll_to_post(post_number)
    5.times do
      break if page.has_css?("#post_#{post_number} .cooked", visible: :all, wait: 0)
      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    end
  end

  before do
    Fabricate(:topic_localization, topic:, locale: "es", fancy_title: "Estrategias de vida de ...")

    Fabricate(:post_localization, post: post_1, locale: "ja", cooked: "傑作は単なる軍事戦略についてではありません")
    Fabricate(:post_localization, post: post_2, locale: "ja", cooked: "最大の勝利は戦いを必要としないものです")
    Fabricate(:post_localization, post: post_3, locale: "en", cooked: "A general is one who ..")
    SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  context "when the feature is enabled for English and Japanese" do
    before do
      SiteSetting.allow_user_locale = true
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_allowed_groups =
        "#{Group::AUTO_GROUPS[:admins]}|#{jap_group.id}"
      SiteSetting.content_localization_supported_locales = "en|ja"
    end

    it "shows the user's language based on their user locale" do
      sign_in(japanese_user)

      visit("/t/#{topic.id}")
      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
    end

    it "shows original content when 'Show Original' is selected" do
      sign_in(japanese_user)

      visit("/")
      topic_list.visit_topic_with_title("孫子兵法からの人生戦略")

      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)

      expect(page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR)["title"]).to eq(
        I18n.t("js.content_localization.toggle_localized.translated"),
      )
      page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click

      expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)
      expect(page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR)["title"]).to eq(
        I18n.t("js.content_localization.toggle_localized.not_translated"),
      )

      visit("/")
      topic_list.visit_topic_with_title("Life strategies from The Art of War")
    end

    it "allows users to set their post's locale when posting" do
      sign_in(japanese_user)

      visit("/")
      topic_list.visit_topic_with_title("孫子兵法からの人生戦略")

      topic_page.click_post_action_button(post_1, :reply)
      expect(composer).to be_opened
      expect(composer.locale.text.gsub(/\u200B/, "")).to be_blank

      composer.set_locale("日本語")
      composer.fill_content("この小説は、名前のない猫の視点から明治時代の人間社会を風刺的に描いています。")
      composer.create

      new_post = Post.find_by(post_number: 4, topic_id: topic.id)
      expect(new_post).to_not be_nil
      # simulates a localization that would have been automatically created
      Fabricate(
        :post_localization,
        post: new_post,
        locale: "en",
        cooked:
          "This novel satirically depicts Meiji-era human society from the perspective of a nameless cat.",
      )

      sign_in(site_local_user)

      topic_page.visit_topic(topic)
      expect(post_4_obj.post_language).to have_content("日本語")
    end

    it "shows 'en' posts for 'en_GB' users" do
      brit_user = Fabricate(:user, locale: "en_GB")

      sign_in(brit_user)
      visit("/")

      topic_list.visit_topic_with_title("Life strategies from The Art of War")
      expect(post_3_obj.post).to have_content("A general is one who ..")
    end

    context "with tl parameter" do
      before do
        SiteSetting.set_locale_from_param = true
        SiteSetting.set_locale_from_cookie = true
      end

      fab!(:topic2) do
        topic = Fabricate(:topic, title: "The Life of Oda Nobunaga", locale: "en", user: admin)
        Fabricate(:post, topic:, locale: "en", raw: "Oda Nobunaga was a powerful daimyo ...")
        topic
      end
      fab!(:topic_localization2) do
        Fabricate(:topic_localization, topic: topic2, locale: "ja", fancy_title: "織田信長の生涯")
      end

      it "persists locale for anonymous users across page views" do
        visit("/t/#{topic.id}?tl=ja")
        expect(topic_page.topic_title).to have_content("孫子兵法からの人生戦略")

        visit("/t/#{topic2.id}")
        expect(topic_page.topic_title).to have_content("織田信長の生涯")
      end

      it "ignores tl parameter for logged-in users" do
        sign_in(site_local_user)
        visit("/t/#{topic.id}?tl=ja")

        expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)
      end
    end

    context "when editing" do
      let(:edit_localized_post_dialog) { PageObjects::Components::Dialog.new }
      let(:fast_editor) { PageObjects::Components::FastEditor.new }

      it "allows editing original content when post is localized" do
        sign_in(admin)

        topic_page.visit_topic(topic)
        topic_page.expand_post_actions(post_3)
        topic_page.click_post_action_button(post_3, :edit)
        expect(edit_localized_post_dialog).to be_open
        edit_localized_post_dialog.click_yes
        expect(composer).to have_content(post_3.raw)
      end

      it "allows editing translated content when post is localized" do
        sign_in(admin)

        topic_page.visit_topic(topic)
        topic_page.expand_post_actions(post_3)
        topic_page.click_post_action_button(post_3, :edit)
        expect(edit_localized_post_dialog).to be_open
        edit_localized_post_dialog.click_no
        expect(page).to have_css(".action-title", text: I18n.t("js.composer.translations.title"))
      end

      it "does not open the fast editor for localized posts" do
        sign_in(admin)

        topic_page.visit_topic(topic)
        select_text_range("#{topic_page.post_by_number_selector(post_3.post_number)} .cooked", 0, 5)
        expect(topic_page.fast_edit_button).to be_visible
        topic_page.click_fast_edit_button
        expect(page).to have_no_css("#fast-edit-input")
        expect(edit_localized_post_dialog).to be_open
      end

      context "for topic titles" do
        fab!(:untranslated_topic) { Fabricate(:post).topic }

        it "shows inline title editor when user can edit localizations" do
          sign_in(japanese_user)

          topic_page.visit_topic(untranslated_topic)
          # not privileged therefore cannot edit topic title via title container
          topic_page.click_topic_edit_title
          expect(topic_page).to have_no_topic_title_editor

          topic_page.visit_topic(topic)

          topic_page.click_topic_edit_title
          expect(topic_page).to have_topic_title_editor
          expect(topic_page).to have_editing_localization_indicator
          expect(page).to have_field("edit-title", with: topic_ja_localization.title)
        end

        it "opens a dialog for choosing which title to edit for admins when title is localized" do
          admin.update(locale: "ja")

          sign_in(admin)

          topic_page.visit_topic(untranslated_topic)
          topic_page.click_topic_edit_title
          expect(topic_page).to have_topic_title_editor
          expect(topic_page).to have_no_editing_localization_indicator

          topic_page.click_topic_title_cancel_edit

          topic_page.visit_topic(topic)
          original_translated_title = topic_ja_localization.fancy_title
          expect(topic_page).to have_topic_title(original_translated_title)
          topic_page.click_topic_edit_title
          expect(edit_localized_post_dialog).to be_open

          # Viewing translation - Edit Original
          edit_localized_post_dialog.click_yes
          expect(topic_page).to have_topic_title_editor
          expect(topic_page).to have_no_editing_localization_indicator
          expect(page).to have_field("edit-title", with: topic.title)

          # Viewing translation - Save original title change and displayed title should NOT update (still viewing translation)
          find("#edit-title").fill_in(with: "New Original Title")
          topic_page.click_topic_title_submit_edit
          expect(topic_page).to have_topic_title(original_translated_title)

          # View original - displayed title should update to new original title
          page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click
          expect(topic_page).to have_topic_title("New Original Title")

          # switch back to Japanese to test translation editing
          page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click

          # Viewing translation - Edit translation
          topic_page.click_topic_edit_title
          expect(edit_localized_post_dialog).to be_open
          edit_localized_post_dialog.click_no
          expect(topic_page).to have_topic_title_editor
          expect(topic_page).to have_editing_localization_indicator
          expect(page).to have_field("edit-title", with: topic_ja_localization.title)

          # Viewing translation - Save translation title change and displayed title should update immediately
          find("#edit-title").fill_in(with: "New Japanese Title")
          topic_page.click_topic_title_submit_edit
          expect(topic_page).to have_topic_title("New Japanese Title")
          page.refresh
          expect(topic_page).to have_topic_title("New Japanese Title")
        end

        it "discards changes when cancelled" do
          admin.update(locale: "ja")
          sign_in(admin)

          topic_page.visit_topic(topic)
          original_title = topic_ja_localization.fancy_title

          topic_page.click_topic_edit_title
          edit_localized_post_dialog.click_no

          find("#edit-title").fill_in(with: "Changed Title")
          topic_page.click_topic_title_cancel_edit

          expect(topic_page).to have_topic_title(original_title)
        end
      end
    end

    context "for post edit histories" do
      let(:post_history_modal) { PageObjects::Modals::PostHistory.new }

      before do
        SiteSetting.editing_grace_period = 0
        PostRevisor.new(post_1).revise!(Discourse.system_user, { raw: post_1.raw, locale: "" })
        PostRevisor.new(post_1).revise!(Discourse.system_user, { raw: post_1.raw, locale: "ja" })
      end

      it "shows the language of the post in history modal" do
        sign_in(admin)

        visit("/")
        topic_list.visit_topic_with_title(topic.title)

        post_1_obj.open_post_history
        expect(post_history_modal.current_locale).to have_content("日本語")
        expect(post_history_modal.previous_locale).to have_content(
          I18n.t("js.post.revisions.locale.no_locale_set"),
        )

        post_history_modal.click_previous_revision
        expect(post_history_modal.current_locale).to have_content(
          I18n.t("js.post.revisions.locale.locale_removed"),
        )
        expect(post_history_modal.previous_locale).to have_content("English")
      end
    end

    context "when loading 20+ posts in stream" do
      before do
        highest = topic.highest_post_number
        22.times do |i|
          post_number = i + highest + 1
          post =
            Fabricate(
              :post,
              topic: topic,
              locale: "ja",
              raw: "Japanese content for post #{post_number}",
              cooked: "<p>日本語コンテンツ #{post_number}</p>",
            )

          Fabricate(
            :post_localization,
            post:,
            locale: "en",
            cooked: "<p>English translation #{post_number}</p>",
          )
        end
      end

      let(:post_21_obj) { PageObjects::Components::Post.new(21) }

      it "respects the show_original toggle for posts loaded dynamically when scrolling (20+ posts)" do
        sign_in(site_local_user)
        visit("/")

        topic_page.visit_topic(topic)

        expect(post_3_obj.post).to have_content("A general is one who ..")
        expect(topic_page).to have_post_content(post_number: 3, content: "A general is one who ..")

        scroll_to_post(21)

        expect(page).to have_css("#post_21")
        expect(topic_page).to have_post_content(post_number: 21, content: "English translation 21")

        # toggle should show correct state of post content
        page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click
        scroll_to_post(21)
        expect(post_21_obj.post).to have_content("日本語コンテンツ 21")

        # refresh should show correct state of post content
        page.refresh
        scroll_to_post(21)
        expect(post_21_obj.post).to have_content("日本語コンテンツ 21")
      end
    end

    context "for html title" do
      fab!(:shady_topic) do
        topic =
          Fabricate(
            :topic,
            title: "topic with — <script>alert('xss')</script> …",
            locale: "en",
            user: site_local_user,
          )
        Fabricate(:post, topic:, locale: "en")
        topic
      end

      fab!(:shady_topic_ja_localization) do
        Fabricate(:topic_localization, topic: shady_topic, locale: "ja")
      end

      it "shows localized fancy_title in HTML title when user locale differs" do
        sign_in(japanese_user)

        topic_page.visit_topic(shady_topic)
        expect(page).to have_title(shady_topic_ja_localization.fancy_title)

        page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click
        expect(page).to have_title(shady_topic.title)

        page.find(TOGGLE_LOCALIZE_BUTTON_SELECTOR).click
        expect(page).to have_title(shady_topic_ja_localization.fancy_title)

        SiteSetting.content_localization_enabled = false
        page.refresh

        expect(page).to have_title(shady_topic.title)
      end
    end

    context "for a Greek user in an English forum with Japanese users" do
      fab!(:greek_user) { Fabricate(:user, locale: "el") }

      fab!(:jap_post) { Fabricate(:post, locale: "ja", cooked: "皆さんは「ジョジョの奇妙な冒険」をご存知ですか？") }
      fab!(:jap_topic) do
        jap_post.topic.tap { |t| t.update(locale: "ja", fancy_title: "ジョジョの奇妙な冒険") }
      end
      fab!(:en_loc_jap_post) do
        Fabricate(
          :post_localization,
          locale: "en",
          post: jap_post,
          cooked: "Do you know “JoJo’s Bizarre Adventure”?",
        )
      end
      fab!(:en_loc_jap_topic) do
        Fabricate(
          :topic_localization,
          locale: "en",
          topic: jap_topic,
          fancy_title: "JoJo's Bizarre Adventure",
        )
      end

      before do
        SiteSetting.default_locale = "en" # explicit
        SiteSetting.content_localization_use_default_locale_when_unsupported = true
      end

      context "for a topic / post with no locale" do
        it "shows content as-is" do
          jap_post.update(locale: nil)
          jap_topic.update(locale: nil)

          sign_in(greek_user)

          topic_page.visit_topic(jap_topic)
          expect(topic_page).to have_topic_title(jap_topic.fancy_title)
          expect(post_1_obj).to have_cooked_content(jap_post.cooked)

          SiteSetting.content_localization_enabled = false

          page.refresh
          expect(topic_page).to have_topic_title(jap_topic.fancy_title)
          expect(post_1_obj).to have_cooked_content(jap_post.cooked)
        end
      end

      context "for a topic / post written in Site default language (en)" do
        it "shows Site default language (en) translation to Greek user" do
          sign_in(greek_user)

          topic_page.visit_topic(jap_topic)
          expect(topic_page).to have_topic_title(en_loc_jap_topic.fancy_title)
          expect(post_1_obj).to have_cooked_content(en_loc_jap_post.cooked)

          SiteSetting.content_localization_use_default_locale_when_unsupported = false

          page.refresh
          expect(topic_page).to have_topic_title(jap_topic.fancy_title)
          expect(post_1_obj).to have_cooked_content(jap_post.cooked)
        end
      end

      it "shows content as-is when no localization exists" do
        en_loc_jap_topic.destroy
        en_loc_jap_post.destroy

        sign_in(greek_user)

        topic_page.visit_topic(jap_topic)
        expect(topic_page).to have_topic_title(jap_topic.fancy_title)
        expect(post_1_obj).to have_cooked_content(jap_post.cooked)
      end
    end

    context "for tags" do
      SWITCHER_SELECTOR = "button[data-identifier='language-switcher']"

      let(:discovery) { PageObjects::Pages::Discovery.new }
      let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }
      let(:switcher) { PageObjects::Components::DMenu.new(SWITCHER_SELECTOR) }

      fab!(:tag) { Fabricate(:tag, name: "strategy", locale: "en") }
      fab!(:tag_localization) { Fabricate(:tag_localization, tag:, locale: "ja", name: "戦略") }
      fab!(:topic_tag) { Fabricate(:topic_tag, topic:, tag:) }

      before do
        SiteSetting.tagging_enabled = true
        SiteSetting.navigation_menu = "sidebar"
        SiteSetting.default_navigation_menu_tags = tag.name
        SiteSetting.set_locale_from_cookie = true
        SiteSetting.content_localization_language_switcher = "all"
      end

      it "displays localized tag names in sidebar, topic list, tag dropdown, and topic view" do
        sign_in(japanese_user)

        visit("/")

        expect(sidebar).to have_section_link("戦略")
        expect(topic_list).to have_topic_tag(topic, "戦略")

        discovery.tag_drop.expand
        expect(discovery.tag_drop).to have_option_name("戦略")
        discovery.tag_drop.collapse

        topic_list.visit_topic_with_title("孫子兵法からの人生戦略")
        expect(page).to have_css(".title-wrapper .discourse-tag", text: "戦略")

        switcher.expand
        switcher.option("[data-menu-option-id='en']").click

        visit("/")
        expect(sidebar).to have_section_link("strategy")
        expect(topic_list).to have_topic_tag(topic, "strategy")

        discovery.tag_drop.expand
        expect(discovery.tag_drop).to have_option_name("strategy")
        discovery.tag_drop.collapse

        topic_list.visit_topic_with_title("Life strategies from The Art of War")
        expect(page).to have_css(".title-wrapper .discourse-tag", text: "strategy")
      end
    end
  end

  context "with author localization" do
    fab!(:author) { Fabricate(:user, locale: "en") }
    fab!(:author_post) do
      Fabricate(:post, topic:, user: author, locale: "en", raw: "Author's original post")
    end

    before do
      SiteSetting.allow_user_locale = true
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}"
      SiteSetting.content_localization_supported_locales = "en|ja"
      SiteSetting.post_menu = "addTranslation"
    end

    it "only shows globe icon on author's own posts" do
      SiteSetting.content_localization_allow_author_localization = false

      sign_in(author)
      topic_page.visit_topic(topic)

      expect(topic_page).to have_no_post_action_button(post_1, :add_translation)
      expect(topic_page).to have_no_post_action_button(author_post, :add_translation)

      SiteSetting.content_localization_allow_author_localization = true
      page.refresh
      expect(topic_page).to have_post_action_button(author_post, :add_translation)
      topic_page.click_post_action_button(author_post, :add_translation)
      find(".post-action-menu__add-translation").click
      expect(translation_composer).to be_opened

      translation_composer.select_locale("Japanese (日本語)")
      translation_composer.fill_content("著者のオリジナル投稿")
      translation_composer.create

      sign_in(japanese_user)
      topic_page.visit_topic(topic)
      expect(topic_page).to have_post_content(
        post_number: author_post.post_number,
        content: "著者のオリジナル投稿",
      )
    end

    it "shows globe icon for admins on all posts" do
      sign_in(admin)
      topic_page.visit_topic(topic)

      expect(topic_page).to have_post_action_button(post_1, :add_translation)
      expect(topic_page).to have_post_action_button(post_2, :add_translation)
      expect(topic_page).to have_post_action_button(author_post, :add_translation)
    end
  end

  context "for site settings" do
    let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
    let(:banner) { PageObjects::Components::AdminChangesBanner.new }

    it "does not allow more than the maximum number of locales" do
      SiteSetting.content_localization_supported_locales = "en|ja"
      SiteSetting.content_localization_max_locales = 2
      sign_in(admin)

      settings_page.visit("content_localization_supported_locales")
      expect(settings_page.find_setting("content_localization_supported_locales")).to have_content(
        "English, Japanese",
      )

      settings_page.select_list_values("content_localization_supported_locales", %w[es])
      settings_page.save_setting("content_localization_supported_locales")
      expect(settings_page.error_message("content_localization_supported_locales")).to have_content(
        I18n.t(
          "site_settings.errors.content_localization_locale_limit",
          max: SiteSetting.content_localization_max_locales,
        ),
      )
    end
  end
end
