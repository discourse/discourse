# frozen_string_literal: true

describe "Lightbox | Photoswipe", type: :system do
  fab!(:topic)
  fab!(:current_user, :admin)
  fab!(:upload_1) { Fabricate(:image_upload, width: 2400, height: 3600) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "![first image](#{upload_1.url})") }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:lightbox) { PageObjects::Components::PhotoSwipe.new(".pswp") }
  let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

  before do
    SiteSetting.experimental_lightbox = true
    SiteSetting.create_thumbnails = true

    sign_in(current_user)
  end

  context "with single image" do
    before do
      cpp.post_process
      post.update(cooked: cpp.html)
    end

    it "has the correct lightbox elements" do
      topic_page.visit_topic(topic)

      find("#post_1 a.lightbox").click

      expect(lightbox).to be_visible

      expect(lightbox).to have_no_counter
      expect(lightbox).to have_caption_title("first image")
      expect(lightbox).to have_caption_details("2400×3600 1.21 KB")

      expect(lightbox).to have_no_next_button
      expect(lightbox).to have_no_prev_button
      expect(lightbox).to have_download_button
      expect(lightbox).to have_original_image_button
    end
  end

  context "with multiple images" do
    fab!(:upload_2) { Fabricate(:large_image_upload, width: 2000, height: 1000) }

    before do
      post.update(raw: "![first image](#{upload_1.url}) ![second image](#{upload_2.url})")

      cpp.post_process
      post.update(cooked: cpp.html)
    end

    it "has the correct lightbox elements" do
      topic_page.visit_topic(topic)

      find("#post_1 .lightbox-wrapper:nth-of-type(2) .lightbox").click

      expect(lightbox).to be_visible

      expect(lightbox).to have_counter("2 / 2")
      expect(lightbox).to have_caption_title("second image")
      expect(lightbox).to have_caption_details("2000×1000 1.21 KB")

      expect(lightbox).to have_next_button
      expect(lightbox).to have_prev_button
      expect(lightbox).to have_download_button
      expect(lightbox).to have_original_image_button
    end
  end
end
