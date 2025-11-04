# frozen_string_literal: true

describe "Lightbox | Photoswipe", type: :system do
  fab!(:topic)
  fab!(:current_user, :admin)
  fab!(:upload_1) { Fabricate(:image_upload, width: 2400, height: 3600) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "![first image](#{upload_1.url})") }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:lightbox) { PageObjects::Components::PhotoSwipe.new }
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
      expect(lightbox).to have_no_caption_details

      expect(lightbox).to have_no_next_button
      expect(lightbox).to have_no_prev_button
      expect(lightbox).to have_download_button
      expect(lightbox).to have_original_image_button
      expect(lightbox).to have_image_info_button
    end

    it "can toggle image info" do
      topic_page.visit_topic(topic)

      find("#post_1 a.lightbox").click

      expect(lightbox).to be_visible
      expect(lightbox).to have_no_caption_details

      lightbox.image_info_button.click

      expect(lightbox).to have_caption_details("2400×3600 1.21 KB")

      lightbox.image_info_button.click

      expect(lightbox).to have_no_caption_details
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
      expect(lightbox).to have_no_caption_details

      expect(lightbox).to have_next_button
      expect(lightbox).to have_prev_button
      expect(lightbox).to have_download_button
      expect(lightbox).to have_original_image_button
      expect(lightbox).to have_image_info_button
    end
  end

  context "when on mobile", mobile: true do
    let(:screen_center_x) { page.evaluate_script("window.innerWidth / 2") }
    let(:screen_center_y) { page.evaluate_script("window.innerHeight / 2") }

    before do
      upload_1.update(width: 400, height: 300)
      cpp.post_process
      post.update(cooked: cpp.html)
    end

    it "toggles UI by tapping image" do
      topic_page.visit_topic(topic)
      find("#post_1 a.lightbox").click

      expect(lightbox).to be_visible
      expect(lightbox).to have_ui_visible

      tap_screen_at(screen_center_x, screen_center_y)
      expect(lightbox).to have_no_ui_visible

      tap_screen_at(screen_center_x, screen_center_y)
      expect(lightbox).to have_ui_visible
    end

    it "closes lightbox by tapping backdrop" do
      topic_page.visit_topic(topic)
      find("#post_1 a.lightbox").click

      expect(lightbox).to be_visible

      tap_screen_at(50, 50)

      expect(lightbox).to be_hidden
    end

    it "toggles image info by clicking button" do
      topic_page.visit_topic(topic)

      find("#post_1 a.lightbox").click

      expect(lightbox).to be_visible
      expect(lightbox).to have_no_caption_details

      lightbox.image_info_button.click

      expect(lightbox).to have_caption_details("400×300 1.21 KB")

      lightbox.image_info_button.click

      expect(lightbox).to have_no_caption_details
    end
  end
end
