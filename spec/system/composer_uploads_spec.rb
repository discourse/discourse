# frozen_string_literal: true

describe "Uploading files in the composer", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }
  let(:cdp) { PageObjects::CDP.new }

  before { sign_in(current_user) }

  # it "uploads multiple files at once" do
  #   visit "/new-topic"
  #   expect(composer).to be_opened

  #   file_path_1 = file_from_fixtures("logo.png", "images").path
  #   file_path_2 = file_from_fixtures("logo.jpg", "images").path
  #   attach_file([file_path_1, file_path_2]) { composer.click_toolbar_button("upload") }

  #   expect(composer).to have_no_in_progress_uploads
  #   expect(composer.preview).to have_css(".image-wrapper", count: 2)
  # end

  # it "allows cancelling uploads" do
  #   visit "/new-topic"
  #   expect(composer).to be_opened

  #   file_path_1 = file_from_fixtures("huge.jpg", "images").path
  #   cdp.with_slow_upload do
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }
  #     expect(composer).to have_in_progress_uploads
  #     find("#cancel-file-upload").click

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_no_css(".image-wrapper")
  #   end
  # end

  # context "when video thumbnails are enabled" do
  #   before do
  #     SiteSetting.video_thumbnails_enabled = true
  #     SiteSetting.authorized_extensions += "|mp4"
  #   end

  #   it "generates a topic preview thumbnail from the video" do
  #     visit "/new-topic"
  #     expect(composer).to be_opened
  #     topic.fill_in_composer_title("Video upload test")

  #     file_path_1 = file_from_fixtures("small.mp4", "media").path
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_css(".onebox-placeholder-container")

  #     composer.submit

  #     expect(find("#topic-title")).to have_content("Video upload test")
  #     expect(Topic.last.image_upload_id).to eq(Upload.last.id)
  #   end

  #   it "generates a thumbnail from the video" do
  #     visit "/new-topic"
  #     expect(composer).to be_opened
  #     topic.fill_in_composer_title("Video upload test")

  #     file_path_1 = file_from_fixtures("small.mp4", "media").path
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_css(".onebox-placeholder-container")

  #     expect(page).to have_css(
  #       '.onebox-placeholder-container[style*="background-image"]',
  #       wait: Capybara.default_max_wait_time,
  #     )

  #     composer.submit

  #     expect(find("#topic-title")).to have_content("Video upload test")

  #     selector = topic.post_by_number_selector(1)

  #     expect(page).to have_css(selector)
  #     within(selector) do
  #       expect(page).to have_css(".video-placeholder-container[data-thumbnail-src]")
  #     end
  #   end

  #   it "handles a video where dimensions can't be read gracefully" do
  #     visit "/new-topic"
  #     expect(composer).to be_opened
  #     topic.fill_in_composer_title("Zero Width Video Test")

  #     # Inject JavaScript to mock video dimensions
  #     page.execute_script <<-JS
  #       HTMLVideoElement.prototype.__defineGetter__('videoWidth', function() { return 0; });
  #       HTMLVideoElement.prototype.__defineGetter__('videoHeight', function() { return 0; });
  #     JS

  #     file_path_1 = file_from_fixtures("small.mp4", "media").path
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_css(".onebox-placeholder-container")

  #     composer.submit

  #     expect(find("#topic-title")).to have_content("Zero Width Video Test")

  #     selector = topic.post_by_number_selector(1)

  #     expect(page).to have_css(selector)
  #     within(selector) do
  #       expect(page).to have_no_css(".video-placeholder-container[data-thumbnail-src]")
  #     end
  #   end

  #   it "handles a video load error gracefully" do
  #     visit "/new-topic"
  #     expect(composer).to be_opened
  #     topic.fill_in_composer_title("Video Load Error Test")

  #     # Inject JavaScript to simulate an invalid video file that triggers onerror
  #     page.execute_script <<-JS
  #       const originalCreateObjectURL = URL.createObjectURL;
  #       URL.createObjectURL = function(blob) {
  #         // Simulate an invalid video source by returning a fake object URL
  #         return 'invalid_video_source.mp4';
  #       };
  #     JS

  #     file_path_1 = file_from_fixtures("small.mp4", "media").path
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_css(".onebox-placeholder-container")
  #   end

  #   it "shows video player in composer" do
  #     SiteSetting.enable_diffhtml_preview = true

  #     visit "/new-topic"
  #     expect(composer).to be_opened
  #     topic.fill_in_composer_title("Video upload test")

  #     file_path_1 = file_from_fixtures("small.mp4", "media").path
  #     attach_file(file_path_1) { composer.click_toolbar_button("upload") }

  #     expect(composer).to have_no_in_progress_uploads
  #     expect(composer.preview).to have_css(".video-container video")

  #     expect(page).to have_css(
  #       ".video-container video source[src]",
  #       visible: false,
  #       wait: Capybara.default_max_wait_time,
  #     )
  #   end
  # end

  context "when multiple images are uploaded" do
    before { SiteSetting.experimental_auto_grid_images = true }

    it "automatically wraps images in [grid] tags on 3 or more images" do
      visit "/new-topic"
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      attach_file([file_path_1, file_path_2, file_path_3]) do
        composer.click_toolbar_button("upload")
      end

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end

    it "does not wrap [grid] tags on less than 3 images" do
      visit "/new-topic"
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      attach_file([file_path_1, file_path_2]) { composer.click_toolbar_button("upload") }

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.value).to match(
        %r{!\[.*?\]\(upload://.*?\).*?!\[.*?\]\(upload://.*?\)}m,
      )
    end

    it "automatically wraps images in [grid] tags even after clearing previous uploads" do
      visit "/new-topic"
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      file_path_4 = file_from_fixtures("logo-dev.png", "images").path
      file_path_5 = file_from_fixtures("large_icon_correct.png", "images").path
      file_path_6 = file_from_fixtures("large_icon_incorrect.png", "images").path

      attach_file([file_path_1, file_path_2, file_path_3]) do
        composer.click_toolbar_button("upload")
      end

      expect(composer).to have_no_in_progress_uploads

      expect(composer.composer_input.value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )

      composer.clear_content

      attach_file([file_path_4, file_path_5, file_path_6]) do
        composer.click_toolbar_button("upload")
      end

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end

    it "does not automatically wrap images in [grid] tags when setting is disabled" do
      SiteSetting.experimental_auto_grid_images = false

      visit "/new-topic"
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      attach_file([file_path_1, file_path_2, file_path_3]) do
        composer.click_toolbar_button("upload")
      end

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.value).to match(
        %r{!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\)}m,
      )
    end

    it "does not automatically wrap images in [grid] tags when uploading inside an existing [grid]" do
      visit "/new-topic"
      expect(composer).to be_opened

      composer.fill_content("[grid]\n\n[/grid]")
      composer.move_cursor_after("[grid]\n")

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      attach_file([file_path_1, file_path_2, file_path_3]) do
        composer.click_toolbar_button("upload")
      end
      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end
  end
end
