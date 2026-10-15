# frozen_string_literal: true

describe "Composer - ProseMirror - Images" do
  include_context "with prosemirror editor"

  describe "image toolbar" do
    it "allows scaling image down and up via toolbar" do
      open_composer
      paste_and_click_image
      browser_root.locator(".composer-image-toolbar__zoom-out").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img[data-scale='75']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root.locator(".composer-image-toolbar__zoom-out").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img[data-scale='50']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root.locator(".composer-image-toolbar__zoom-in").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img[data-scale='75']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root.locator(".composer-image-toolbar__zoom-in").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img[data-scale='100']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "allows removing image via toolbar" do
      open_composer
      composer.type_content("Before")
      paste_and_click_image
      browser_root.locator(".composer-image-toolbar__trash").filter(visible: true).click
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".composer-image-node img")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(rich).to PlaywrightMatchers.contain_text(
        browser_text_pattern("Before"),
        useInnerText: true,
      )
    end

    it "hides toolbar when clicking outside image" do
      open_composer
      paste_and_click_image
      expect(
        browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      rich.locator("p").filter(visible: true).click
      expect(
        browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "sets width and height attributes when scaling external images" do
      open_composer
      image = Fabricate(:image_upload)
      composer.type_content("![alt text](#{image.url})")
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".composer-image-node img[width]")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        rich
          .tap do |parent|
            parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
          end
          .locator(".composer-image-node img[height]")
          .filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      browser_root.locator(".composer-image-toolbar__zoom-out").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img[width]").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        rich.locator(".composer-image-node img[height]").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  describe "image URL resolution" do
    it "resolves upload URLs and displays images correctly" do
      open_composer
      cdp.allow_clipboard
      upload1 = Fabricate(:upload)
      upload2 = Fabricate(:upload)
      short_url1 = "upload://#{Upload.base62_sha1(upload1.sha1)}"
      short_url2 = "upload://#{Upload.base62_sha1(upload2.sha1)}"
      browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
        window.urlLookupRequests = 0;
        const originalXHROpen = window.XMLHttpRequest.prototype.open;
        window.XMLHttpRequest.prototype.open = function(method, url) {
          if (url.toString().endsWith('/uploads/lookup-urls')) {
            window.urlLookupRequests++;
          }
          return originalXHROpen.apply(this, arguments);
        };
      JS
      markdown = "![image 1](#{short_url1})\n\n![image 2](#{short_url2})"
      cdp.copy_paste(markdown)
      expect(
        browser_root.locator("img[src='#{upload1.url}'][data-orig-src='#{short_url1}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("img[src='#{upload2.url}'][data-orig-src='#{short_url2}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      # loaded in a single api call
      initial_request_count =
        browser_page.evaluate("function(arguments) { return window.urlLookupRequests }", arg: [])
      expect(initial_request_count).to eq(1)
      composer.toggle_rich_editor
      composer.toggle_rich_editor
      expect(
        browser_root.locator("img[src='#{upload1.url}'][data-orig-src='#{short_url1}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("img[src='#{upload2.url}'][data-orig-src='#{short_url2}']").filter(
          visible: true,
        ),
      ).not_to PlaywrightMatchers.have_count(0)
      # loaded from cache, no new request
      final_request_count =
        browser_page.evaluate("function(arguments) { return window.urlLookupRequests }", arg: [])
      expect(final_request_count).to eq(initial_request_count)
    end
  end

  describe "image alt text display and editing" do
    it "shows alt text input when image is selected" do
      open_composer
      paste_and_click_image
      expect(
        browser_root.locator("[data-identifier='composer-image-alt-text']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".image-alt-text-input__display").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "allows editing alt text by clicking on display" do
      open_composer
      paste_and_click_image
      browser_root.locator(".image-alt-text-input__display").filter(visible: true).click
      expect(
        browser_root.locator(".image-alt-text-input.--expanded").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".image-alt-text-input__field").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root
        .locator(".image-alt-text-input__field")
        .filter(visible: true)
        .fill("updated alt text")
      browser_root.locator(".image-alt-text-input__field").filter(visible: true).press("Enter")
      expect(
        rich.locator(".composer-image-node img").filter(visible: true).get_attribute("alt"),
      ).to eq("updated alt text")
    end

    it "saves alt text when leaving the input field" do
      open_composer
      paste_and_click_image
      browser_root.locator(".image-alt-text-input__display").filter(visible: true).click
      browser_root
        .locator(".image-alt-text-input__field")
        .filter(visible: true)
        .fill("new alt text")
      rich.locator("p").filter(visible: true).click
      expect(
        rich.locator(".composer-image-node img").filter(visible: true).get_attribute("alt"),
      ).to eq("new alt text")
    end

    it "displays the placeholder if alt text is empty" do
      open_composer
      paste_and_click_image
      expect(
        browser_root.locator(".image-alt-text-input__display").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("image")], useInnerText: true)
      browser_root.locator(".image-alt-text-input__display").filter(visible: true).click
      browser_root.locator(".image-alt-text-input__field").filter(visible: true).fill("")
      browser_root.locator(".image-alt-text-input__field").filter(visible: true).press("Enter")
      expect(
        browser_root.locator(".image-alt-text-input__display").filter(visible: true),
      ).to PlaywrightMatchers.contain_text(
        [browser_text_pattern(I18n.t("js.composer.image_alt_text.title"))],
        useInnerText: true,
      )
    end
  end

  describe "image grid functionality" do
    context "when images are outside a grid" do
      it "shows 'Add to Grid' button for images outside grids" do
        open_composer
        composer.type_content("![image1](upload://test1.png)")
        expect(composer.image_grid).to have_add_to_grid_toolbar
      end

      it "creates single-image grid" do
        open_composer
        composer.type_content("![image1](upload://test1.png)")
        expect(composer.image_grid).to have_images(1)
        composer.image_grid.add_image_to_grid
        expect(composer.image_grid).to have_grid_images(1)
      end
    end

    context "when images are within a grid" do
      it "shows 'Move outside grid' button for images inside grids" do
        open_composer
        composer.type_content("[grid]![image1](upload://test1.png)![image2](upload://test2.png)")
        composer.image_grid.select_first_grid_image
        expect(composer.image_grid).to have_move_outside_grid_toolbar
      end

      it "moves image outside grid" do
        open_composer
        composer.type_content("[grid]![image1](upload://test1.png)![image2](upload://test2.png)")
        composer.image_grid.move_image_outside_grid
        expect(composer.image_grid).to have_grid_images(1)
        expect(composer.image_grid).to have_images(2) # One in grid, one standalone
      end

      it "moves last image outside grid" do
        open_composer
        composer.type_content("[grid]![image1](upload://test1.png)")
        composer.image_grid.move_image_outside_grid
        expect(composer.image_grid).to have_images(1)
        expect(composer.image_grid).to have_no_grid_images
      end
    end
  end

  describe "auto-grid functionality with enable_auto_grid_images" do
    before { SiteSetting.enable_auto_grid_images = true }

    it "automatically wraps 3+ uploaded images in a grid" do
      open_composer
      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])
      expect(composer).to have_no_in_progress_uploads
      # Should automatically create a grid with 3 images
      expect(composer.image_grid).to have_grid_images(3)
    end

    it "does not create nested grids when uploading images inside an existing grid" do
      open_composer
      composer.type_content("[grid]![image1](upload://test1.png)![image2](upload://test2.png)")
      expect(composer.image_grid).to have_grid_images(2)
      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      browser_root.locator(
        "input[type='file']:not(:disabled)[id=#{"file-uploader".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"file-uploader".to_s.to_json}]",
      ).set_input_files([file_path_1, file_path_2, file_path_3])
      expect(composer).to have_no_in_progress_uploads
      expect(composer.image_grid).to have_single_grid_with_images(5)
    end
  end

  describe "image lightbox" do
    let(:lightbox) { PageObjects::Components::PhotoSwipe.new }

    def click_selected_image
      browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
        document.querySelector('.composer-image-node img.ProseMirror-selectednode')?.click();
      JS
    end

    it "opens lightbox with single image" do
      open_composer
      paste_and_click_image

      click_selected_image

      expect(lightbox).to be_visible
      expect(lightbox).to have_no_counter
      expect(lightbox).to have_no_next_button
      expect(lightbox).to have_no_prev_button

      lightbox.close_button.click
      expect(lightbox).to be_hidden

      expect(
        rich.locator(".composer-image-node img.ProseMirror-selectednode").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "opens lightbox with gallery when multiple images are present" do
      open_composer
      composer.type_content("![image1](upload://test1.png)\n\n![image2](upload://test2.png)")

      first_image =
        rich
          .locator(".composer-image-node img")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .first
      first_image.click
      expect(first_image.get_attribute("class")).to include("ProseMirror-selectednode")

      click_selected_image

      expect(lightbox).to be_visible
      expect(
        lightbox.locator(".pswp__counter").filter(visible: true),
      ).to PlaywrightMatchers.contain_text([browser_text_pattern("1 / 2")], useInnerText: true)
      expect(lightbox).to have_next_button
      expect(lightbox).to have_prev_button

      lightbox.close_button.click
      expect(lightbox).to be_hidden

      expect(
        rich.locator(".composer-image-node img.ProseMirror-selectednode").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("[data-identifier='composer-image-toolbar']").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "lets the user dismiss the alt text input by clicking the image without opening the lightbox" do
      open_composer
      paste_and_click_image

      browser_root.locator(".image-alt-text-input__display").filter(visible: true).click
      browser_root
        .locator(".image-alt-text-input__field")
        .filter(visible: true)
        .fill("described image")

      click_selected_image

      expect(
        browser_root.locator(".image-alt-text-input.--expanded").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        rich.locator(".composer-image-node img").filter(visible: true).get_attribute("alt"),
      ).to eq("described image")
      expect(browser_root.locator(".pswp").filter(visible: true)).to PlaywrightMatchers.have_count(
        0,
      )

      click_selected_image
      expect(lightbox).to be_visible
    end

    it "navigates between images using prev/next buttons" do
      open_composer
      composer.type_content("![first](upload://test1.png)\n\n![second](upload://test2.png)")

      first_image = rich.locator(".composer-image-node img[alt='first']").filter(visible: true)
      first_image.click
      expect(first_image).to PlaywrightMatchers.have_class(/ProseMirror-selectednode/)
      click_selected_image

      expect(lightbox).to be_visible
      expect(lightbox).to have_caption_title("first")

      lightbox.next_button.click
      expect(lightbox).to have_caption_title("second")

      lightbox.prev_button.click
      expect(lightbox).to have_caption_title("first")
    end
  end
end
