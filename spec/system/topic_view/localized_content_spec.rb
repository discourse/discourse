# frozen_string_literal: true

RSpec.describe "Localized topic" do
  fab!(:japanese_user) { Fabricate(:user, locale: "ja") }
  fab!(:site_local_user) { Fabricate(:user, locale: "en") }
  fab!(:author) { Fabricate(:user) }

  fab!(:topic) do
    Fabricate(:topic, title: "Life strategies from The Art of War", locale: "en", user: author)
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

  before do
    Fabricate(:topic_localization, topic:, locale: "ja", fancy_title: "孫子兵法からの人生戦略")
    Fabricate(:topic_localization, topic:, locale: "es", fancy_title: "Estrategias de vida de ...")

    Fabricate(:post_localization, post: post_1, locale: "ja", cooked: "傑作は単なる軍事戦略についてではありません")
    Fabricate(:post_localization, post: post_2, locale: "ja", cooked: "最大の勝利は戦いを必要としないものです")
    Fabricate(:post_localization, post: post_3, locale: "en", cooked: "A general is one who ..")
  end

  context "when the feature is enabled" do
    before do
      SiteSetting.allow_user_locale = true
      SiteSetting.experimental_content_localization = true
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
  end
end
