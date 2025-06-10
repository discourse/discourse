# frozen_string_literal: true

describe "Composer using review_media", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, category: Category.find(SiteSetting.uncategorized_category_id)) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.skip_review_media_groups = Group::AUTO_GROUPS[:trust_level_3]
    sign_in(current_user)
  end

  it "does not flag a post with an emoji" do
    topic_page.visit_topic_and_open_composer(topic)
    topic_page.fill_in_composer(" this one has an emoji: :mask: ")

    expect(page).to have_css(".d-editor-preview .emoji")

    topic_page.send_reply

    expect(topic_page).to have_post_number(2)
    expect(page).not_to have_css(".post-enqueued-modal")
  end

  it "flags a post with an image" do
    topic_page.visit_topic_and_open_composer(topic)
    topic_page.fill_in_composer(" this one has an upload: ")
    attach_file(file_from_fixtures("logo.jpg", "images").path) do
      composer.click_toolbar_button("upload")
    end

    expect(page).to have_css(".d-editor-preview img")

    topic_page.send_reply

    expect(page).to have_css(".post-enqueued-modal")
  end
end
