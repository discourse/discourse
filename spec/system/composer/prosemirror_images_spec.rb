# frozen_string_literal: true

describe "Composer - ProseMirror - Images", type: :system do
  include_context "with prosemirror editor"

  describe "image toolbar" do
    it "allows scaling image down and up via toolbar" do
      open_composer
      paste_and_click_image
      find(".composer-image-toolbar__zoom-out").click
      expect(rich).to have_selector(".composer-image-node img[data-scale='75']")
      find(".composer-image-toolbar__zoom-out").click
      expect(rich).to have_selector(".composer-image-node img[data-scale='50']")
      find(".composer-image-toolbar__zoom-in").click
      expect(rich).to have_selector(".composer-image-node img[data-scale='75']")
      find(".composer-image-toolbar__zoom-in").click
      expect(rich).to have_selector(".composer-image-node img[data-scale='100']")
    end

    it "allows removing image via toolbar" do
      open_composer
      composer.type_content("Before")
      paste_and_click_image
      find(".composer-image-toolbar__trash").click
      expect(rich).to have_no_css(".composer-image-node img")
      expect(rich).to have_content("Before")
    end

    it "hides toolbar when clicking outside image" do
      open_composer
      paste_and_click_image
      expect(page).to have_css("[data-identifier='composer-image-toolbar']")
      rich.find("p").click
      expect(page).to have_no_css("[data-identifier='composer-image-toolbar']")
    end

    it "sets width and height attributes when scaling external images" do
      open_composer
      image = Fabricate(:image_upload)
      composer.type_content("![alt text](#{image.url})")
      expect(rich).to have_no_css(".composer-image-node img[width]")
      expect(rich).to have_no_css(".composer-image-node img[height]")
      find(".composer-image-toolbar__zoom-out").click
      expect(rich).to have_css(".composer-image-node img[width]")
      expect(rich).to have_css(".composer-image-node img[height]")
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
      page.execute_script(<<~JS)
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
      expect(page).to have_css("img[src='#{upload1.url}'][data-orig-src='#{short_url1}']")
      expect(page).to have_css("img[src='#{upload2.url}'][data-orig-src='#{short_url2}']")
      # loaded in a single api call
      initial_request_count = page.evaluate_script("window.urlLookupRequests")
      expect(initial_request_count).to eq(1)
      composer.toggle_rich_editor
      composer.toggle_rich_editor
      expect(page).to have_css("img[src='#{upload1.url}'][data-orig-src='#{short_url1}']")
      expect(page).to have_css("img[src='#{upload2.url}'][data-orig-src='#{short_url2}']")
      # loaded from cache, no new request
      final_request_count = page.evaluate_script("window.urlLookupRequests")
      expect(final_request_count).to eq(initial_request_count)
    end
  end

  describe "image alt text display and editing" do
    it "shows alt text input when image is selected" do
      open_composer
      paste_and_click_image
      expect(page).to have_css("[data-identifier='composer-image-alt-text']")
      expect(page).to have_css(".image-alt-text-input__display")
    end

    it "allows editing alt text by clicking on display" do
      open_composer
      paste_and_click_image
      find(".image-alt-text-input__display").click
      expect(page).to have_css(".image-alt-text-input.--expanded")
      expect(page).to have_css(".image-alt-text-input__field")
      find(".image-alt-text-input__field").fill_in(with: "updated alt text")
      find(".image-alt-text-input__field").send_keys(:enter)
      expect(rich.find(".composer-image-node img")["alt"]).to eq("updated alt text")
    end

    it "saves alt text when leaving the input field" do
      open_composer
      paste_and_click_image
      find(".image-alt-text-input__display").click
      find(".image-alt-text-input__field").fill_in(with: "new alt text")
      rich.find("p").click
      expect(rich.find(".composer-image-node img")["alt"]).to eq("new alt text")
    end

    it "displays the placeholder if alt text is empty" do
      open_composer
      paste_and_click_image
      expect(page).to have_css(".image-alt-text-input__display", text: "image")
      find(".image-alt-text-input__display").click
      find(".image-alt-text-input__field").fill_in(with: "")
      find(".image-alt-text-input__field").send_keys(:enter)
      expect(page).to have_css(
        ".image-alt-text-input__display",
        text: I18n.t("js.composer.image_alt_text.title"),
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

  describe "auto-grid functionality with experimental_auto_grid_images" do
    before { SiteSetting.experimental_auto_grid_images = true }
    it "automatically wraps 3+ uploaded images in a grid" do
      open_composer
      file_path_1 = file_from_fixtures("logo.png", "images").path
      file_path_2 = file_from_fixtures("logo.jpg", "images").path
      file_path_3 = file_from_fixtures("downsized.png", "images").path
      attach_file("file-uploader", [file_path_1, file_path_2, file_path_3], make_visible: true)
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
      attach_file("file-uploader", [file_path_1, file_path_2, file_path_3], make_visible: true)
      expect(composer).to have_no_in_progress_uploads
      expect(composer.image_grid).to have_single_grid_with_images(5)
    end
  end

  describe "image lightbox" do
    let(:lightbox) { PageObjects::Components::PhotoSwipe.new }

    def click_selected_image_to_open_lightbox
      page.execute_script(<<~JS)
        document.querySelector('.composer-image-node img.ProseMirror-selectednode')?.click();
      JS
    end

    it "opens lightbox with single image" do
      open_composer
      paste_and_click_image

      click_selected_image_to_open_lightbox

      expect(lightbox).to be_visible
      expect(lightbox).to have_no_counter
      expect(lightbox).to have_no_next_button
      expect(lightbox).to have_no_prev_button

      lightbox.close_button.click
      expect(lightbox).to be_hidden

      expect(rich).to have_css(".composer-image-node img.ProseMirror-selectednode")
      expect(page).to have_css("[data-identifier='composer-image-toolbar']")
    end

    it "opens lightbox with gallery when multiple images are present" do
      open_composer
      composer.type_content("![image1](upload://test1.png)\n\n![image2](upload://test2.png)")

      first_image = rich.all(".composer-image-node img").first
      first_image.click
      expect(first_image[:class]).to include("ProseMirror-selectednode")

      click_selected_image_to_open_lightbox

      expect(lightbox).to be_visible
      expect(lightbox).to have_css(".pswp__counter", text: "1 / 2")
      expect(lightbox).to have_next_button
      expect(lightbox).to have_prev_button

      lightbox.close_button.click
      expect(lightbox).to be_hidden

      expect(rich).to have_css(".composer-image-node img.ProseMirror-selectednode")
      expect(page).to have_css("[data-identifier='composer-image-toolbar']")
    end

    it "navigates between images using prev/next buttons" do
      open_composer
      composer.type_content("![first](upload://test1.png)\n\n![second](upload://test2.png)")

      rich.find(".composer-image-node img[alt='first']").click
      click_selected_image_to_open_lightbox

      expect(lightbox).to be_visible
      expect(lightbox).to have_caption_title("first")

      lightbox.next_button.click
      expect(lightbox).to have_caption_title("second")

      lightbox.prev_button.click
      expect(lightbox).to have_caption_title("first")
    end
  end
end
