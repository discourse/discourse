# frozen_string_literal: true

describe "Post translations", type: :system do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:translation_selector) do
    PageObjects::Components::SelectKit.new(".translation-selector-dropdown")
  end

  before do
    sign_in(user)
    SiteSetting.experimental_content_localization_supported_locales = "en|fr|es|pt_BR"
    SiteSetting.experimental_content_localization = true
    SiteSetting.experimental_content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.post_menu =
      "read|like|copyLink|flag|edit|bookmark|delete|admin|reply|addTranslation"
  end

  it "allows a user to translate a post" do
    topic_page.visit_topic(topic)
    find("#post_#{post.post_number} .post-action-menu__add-translation").click
    expect(composer).to be_opened
    translation_selector.expand
    translation_selector.select_row_by_value("fr")
    find("#translated-topic-title").fill_in(with: "Ceci est un sujet de test 0")
    composer.fill_content("Bonjour le monde")
    composer.submit
    post.reload
    topic.reload

    try_until_success do
      expect(TopicLocalization.exists?(topic_id: topic.id, locale: "fr")).to be true
      expect(PostLocalization.exists?(post_id: post.id, locale: "fr")).to be true
      expect(PostLocalization.find_by(post_id: post.id, locale: "fr").raw).to eq("Bonjour le monde")
      expect(TopicLocalization.find_by(topic_id: topic.id, locale: "fr").title).to eq(
        "Ceci est un sujet de test 0",
      )
    end
  end
end
