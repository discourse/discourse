# frozen_string_literal: true

describe "Uploading files in the composer" do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }
  let(:cdp) { PageObjects::CDP.new }

  before { sign_in(current_user) }

  it "uploads multiple files at once" do
    browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(composer).to be_opened

    file_path_1 = file_from_fixtures("logo.png", "images").path
    file_path_2 = file_from_fixtures("logo.jpg", "images").path
    browser_root.locator(
      "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
    ).set_input_files([file_path_1, file_path_2])

    expect(composer).to have_no_in_progress_uploads
    expect(composer.preview.locator(".image-wrapper").filter(visible: true)).to have_count(2)
  end

  it "allows cancelling uploads" do
    browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(composer).to be_opened

    file_path_1 = file_from_fixtures("huge.jpg", "images").path
    cdp.with_slow_upload do
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)
      expect(composer).to have_in_progress_uploads
      browser_root.locator("#cancel-file-upload").filter(visible: true).click

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer
          .preview
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".image-wrapper")
          .filter(visible: true),
      ).to have_count(0)
    end
  end

  context "when video thumbnails are enabled" do
    before do
      SiteSetting.video_thumbnails_enabled = true
      SiteSetting.authorized_extensions += "|webm|mp4"
    end

    it "generates a topic preview thumbnail from the video" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.webm", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).not_to have_count(0)

      composer.submit

      expect(browser_root.locator("#topic-title").filter(visible: true)).to contain_text(
        browser_text_pattern("Video upload test"),
        useInnerText: true,
      )
      expect(Topic.last.image_upload_id).to eq(Upload.last.id)
    end

    it "generates a thumbnail from the video" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.webm", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).not_to have_count(0)

      expect(
        browser_root.locator('.onebox-placeholder-container[style*="background-image"]').filter(
          visible: true,
        ),
      ).not_to have_count(0, timeout: Capybara.default_max_wait_time * 1000)

      composer.submit

      expect(browser_root.locator("#topic-title").filter(visible: true)).to contain_text(
        browser_text_pattern("Video upload test"),
        useInnerText: true,
      )

      selector = topic.post_by_number_selector(1)

      expect(browser_root.locator(selector).filter(visible: true)).not_to have_count(0)
      within_browser(selector) do
        expect(
          browser_root.locator(".video-placeholder-container[data-thumbnail-src]").filter(
            visible: true,
          ),
        ).not_to have_count(0)
      end
    end

    it "handles a video where dimensions can't be read gracefully" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Zero Width Video Test")

      # Inject JavaScript to mock video dimensions
      browser_page.evaluate("function(arguments) { #{<<-JS} }", arg: [])
        HTMLVideoElement.prototype.__defineGetter__('videoWidth', function() { return 0; });
        HTMLVideoElement.prototype.__defineGetter__('videoHeight', function() { return 0; });
      JS

      file_path_1 = file_from_fixtures("small.webm", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).not_to have_count(0)

      composer.submit

      expect(browser_root.locator("#topic-title").filter(visible: true)).to contain_text(
        browser_text_pattern("Zero Width Video Test"),
        useInnerText: true,
      )

      selector = topic.post_by_number_selector(1)

      expect(browser_root.locator(selector).filter(visible: true)).not_to have_count(0)
      within_browser(selector) do
        expect(
          browser_root.locator(".video-placeholder-container[data-thumbnail-src]").filter(
            visible: true,
          ),
        ).to have_count(0)
      end
    end

    it "handles a video load error gracefully" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video Load Error Test")

      # Inject JavaScript to simulate an invalid video file that triggers onerror
      browser_page.evaluate("function(arguments) { #{<<-JS} }", arg: [])
        const originalCreateObjectURL = URL.createObjectURL;
        URL.createObjectURL = function(blob) {
          // Simulate an invalid video source by returning a fake object URL
          return 'invalid_video_source.mp4';
        };
      JS

      file_path_1 = file_from_fixtures("small.webm", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).not_to have_count(0)
    end

    it "handles multiple video uploads" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.webm", "media").path
      file_path_2 = file_from_fixtures("small.mp4", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2])

      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).to have_count(2)
    end

    it "handles thumbnail upload errors gracefully without blocking video upload" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened
      topic.fill_in_composer_title("Thumbnail Error Test")

      # Mock canvas.toBlob to fail, simulating a thumbnail generation error
      browser_page.evaluate("function(arguments) { #{<<-JS} }", arg: [])
        HTMLCanvasElement.prototype.toBlob = function(callback, type, quality) {
          // Simulate a failure in blob creation
          setTimeout(() => callback(null), 0);
        };
      JS

      file_path_1 = file_from_fixtures("small.webm", "media").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files(file_path_1)

      # Video upload should complete successfully even if thumbnail generation fails
      expect(composer).to have_no_in_progress_uploads
      expect(
        composer.preview.locator(".onebox-placeholder-container").filter(visible: true),
      ).not_to have_count(0)

      # Video should still be uploadable/submittable
      composer.submit
      expect(browser_root.locator("#topic-title").filter(visible: true)).to contain_text(
        browser_text_pattern("Thumbnail Error Test"),
        useInnerText: true,
      )
    end
  end

  context "when multiple images are uploaded" do
    before { SiteSetting.enable_auto_grid_images = true }

    %w[en fr de].each do |locale|
      before { SiteSetting.default_locale = locale }

      context "when the locale is #{locale}" do
        it "automatically wraps images in [grid] tags on 3 or more images" do
          browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
          expect(composer).to be_opened

          file_path_1 = file_from_fixtures("logo.png", "images").path
          file_path_2 = file_from_fixtures("logo.jpg", "images").path
          file_path_3 = file_from_fixtures("downsized.png", "images").path
          browser_root.locator(
            "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
          ).set_input_files([file_path_1, file_path_2, file_path_3])

          expect(composer).to have_no_in_progress_uploads
          expect(composer.composer_input.input_value).to match(
            %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
          )
        end
      end
    end

    it "does not wrap [grid] tags on less than 3 images" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2])

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.input_value).to match(
        %r{!\[.*?\]\(upload://.*?\).*?!\[.*?\]\(upload://.*?\)}m,
      )
    end

    it "automatically wraps images in [grid] tags even after clearing previous uploads" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      file_path_4 = file_from_fixtures("logo-dev.png", "images").path
      file_path_5 = file_from_fixtures("large_icon_correct.png", "images").path
      file_path_6 = file_from_fixtures("large_icon_incorrect.png", "images").path

      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])

      expect(composer).to have_no_in_progress_uploads

      expect(composer.composer_input.input_value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )

      composer.clear_content

      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_4, file_path_5, file_path_6])

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.input_value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end

    it "does not automatically wrap images in [grid] tags when setting is disabled" do
      SiteSetting.enable_auto_grid_images = false

      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.input_value).to match(
        %r{!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\)}m,
      )
    end

    it "does not automatically wrap images in [grid] tags when uploading inside an existing [grid]" do
      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      composer.fill_content("[grid]\n\n[/grid]")
      composer.move_cursor_after("[grid]\n")

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])
      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.input_value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end

    it "automatically wraps images in [grid] when site language is different" do
      SiteSetting.default_locale = "es"

      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(composer).to be_opened

      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])

      expect(composer).to have_no_in_progress_uploads
      expect(composer.composer_input.input_value).to match(
        %r{\[grid\].*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*!\[.*?\]\(upload://.*?\).*?\[/grid\]}m,
      )
    end
  end
end
