# frozen_string_literal: true

describe "Content Localization" do
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

    it "shows the correct language based on the selected language and login status" do
      sign_in(japanese_user)
      visit("/")
      visit("/t/#{topic.id}")
      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
    end

    it "shows original content when 'Show Original' is selected" do
      sign_in(japanese_user)

      visit("/")
      topic_list.visit_topic_with_title("孫子兵法からの人生戦略")

      expect(topic_page.has_topic_title?("孫子兵法からの人生戦略")).to eq(true)
      page.find("button.btn-toggle-localized-content").click

      expect(topic_page.has_topic_title?("Life strategies from The Art of War")).to eq(true)

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
      try_until_success do
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
      end

      sign_in(site_local_user)

      topic_page.visit_topic(topic)
      expect(post_4_obj.post_language).to have_content("日本語")
    end

    it "allows editing original content when post is localized" do
      sign_in(admin)

      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(post_3)
      topic_page.click_post_action_button(post_3, :edit)
      expect(composer).to have_content(post_3.raw)
    end
  end

  context "for site settings" do
    let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
    let(:banner) { PageObjects::Components::AdminChangesBanner.new }

    it "does not allow more than the maximum number of locales" do
      SiteSetting.content_localization_max_locales = 2
      sign_in(admin)

      settings_page.visit("content_localization_supported_locales")
      settings_page.select_list_values("content_localization_supported_locales", %w[en ja es])
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
