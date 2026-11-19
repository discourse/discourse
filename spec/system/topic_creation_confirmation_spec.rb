# frozen_string_literal: true

describe "Category topic creation confirmation" do
  fab!(:category)
  fab!(:admin)
  fab!(:user) { Fabricate(:user, trust_level: 1) }

  let(:composer) { PageObjects::Components::Composer.new }
  let(:title) { "A topic that follows the posting guidelines" }
  let(:prompt) { "Read the <em>category guidelines</em> before posting." }

  def open_topic_draft
    visit "/new-topic?category_id=#{category.id}"
    composer.fill_title(title)
    composer.fill_content("This topic follows the posting guidelines for this category.")
  end

  it "saves the prompt and maximum trust level through category moderation settings" do
    sign_in(admin)
    category_page = PageObjects::Pages::Category.new
    category_page.visit_moderation(category)

    fill_in I18n.t("js.category.topic_creation_prompt.message"), with: prompt
    fill_in I18n.t("js.category.topic_creation_prompt.max_level"), with: "1"
    category_page.save_settings

    expect(category.reload.topic_creation_prompt).to eq(prompt)
    expect(category.topic_creation_prompt_max_trust_level).to eq(1)
  end

  it "keeps the draft when canceled, and posts once when confirmed" do
    category.update!(topic_creation_prompt: prompt, topic_creation_prompt_max_trust_level: 1)
    sign_in(user)

    open_topic_draft
    composer.submit

    within(".topic-creation-confirmation") do
      expect(page).to have_text(prompt)
      click_button I18n.t("js.composer.topic_creation_confirmation.go_back")
    end
    expect(composer).to be_opened
    expect(Topic.exists?(title:)).to eq(false)

    composer.submit
    within(".topic-creation-confirmation") { click_button I18n.t("js.composer.create_topic") }

    expect(page).to have_css("h1", text: title)
    expect(Topic.where(title:).count).to eq(1)
  end

  it "lets users above the cap post without a prompt" do
    category.update!(topic_creation_prompt: prompt, topic_creation_prompt_max_trust_level: 0)
    sign_in(user)

    open_topic_draft
    composer.submit

    expect(page).to have_css("h1", text: title)
  end
end
