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

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:post_1_obj) { PageObjects::Components::Post.new(1) }
  let(:post_3_obj) { PageObjects::Components::Post.new(3) }
  let(:post_4_obj) { PageObjects::Components::Post.new(4) }

  before do
    Fabricate(:topic_localization, topic:, locale: "ja", fancy_title: "孫子兵法からの人生戦略")
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
        expect(post_history_modal.previous_locale).to have_content("English (US)")
      end
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
        "English (US), Japanese",
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
