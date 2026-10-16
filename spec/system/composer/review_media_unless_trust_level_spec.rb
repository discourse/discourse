# frozen_string_literal: true

describe "Composer using review_media" do
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

    expect(
      browser_root.locator(".d-editor-preview .emoji").filter(visible: true),
    ).not_to have_count(0)

    topic_page.send_reply

    expect(topic_page).to have_post_number(2)
    expect(browser_root.locator(".post-enqueued-modal").filter(visible: true)).to have_count(0)
  end

  it "flags a post with an image" do
    topic_page.visit_topic_and_open_composer(topic)
    topic_page.fill_in_composer(" this one has an upload: ")
    browser_root.locator(
      "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
    ).set_input_files(file_from_fixtures("logo.jpg", "images").path)

    expect(browser_root.locator(".d-editor-preview img").filter(visible: true)).not_to have_count(0)

    topic_page.send_reply

    expect(browser_root.locator(".post-enqueued-modal").filter(visible: true)).not_to have_count(0)
  end
end
