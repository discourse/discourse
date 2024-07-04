# frozen_string_literal: true

describe "Uploading files in the composer", type: :system do
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }
  let(:cdp) { PageObjects::CDP.new }

  before { sign_in(current_user) }

  it "uploads multiple files at once" do
    visit "/new-topic"
    expect(composer).to be_opened

    file_path_1 = file_from_fixtures("logo.png", "images").path
    file_path_2 = file_from_fixtures("logo.jpg", "images").path
    attach_file([file_path_1, file_path_2]) { composer.click_toolbar_button("upload") }

    expect(composer).to have_no_in_progress_uploads
    expect(composer.preview).to have_css(".image-wrapper", count: 2)
  end

  it "allows cancelling uploads" do
    visit "/new-topic"
    expect(composer).to be_opened

    file_path_1 = file_from_fixtures("huge.jpg", "images").path
    cdp.with_slow_upload do
      attach_file(file_path_1) { composer.click_toolbar_button("upload") }
      expect(composer).to have_in_progress_uploads
      find("#cancel-file-upload").click

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_no_css(".image-wrapper")
    end
  end

  context "when video thumbnails are enabled" do
    before do
      SiteSetting.video_thumbnails_enabled = true
      SiteSetting.authorized_extensions += "|mp4"
    end

    it "generates a topic preview thumbnail from the video" do
      visit "/new-topic"
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.mp4", "media").path
      attach_file(file_path_1) { composer.click_toolbar_button("upload") }

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".onebox-placeholder-container")

      composer.submit

      expect(find("#topic-title")).to have_content("Video upload test")
      expect(Topic.last.image_upload_id).to eq(Upload.last.id)
    end

    it "generates a thumbnail from the video" do
      visit "/new-topic"
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.mp4", "media").path
      attach_file(file_path_1) { composer.click_toolbar_button("upload") }

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".onebox-placeholder-container")

      expect(page).to have_css(
        '.onebox-placeholder-container[style*="background-image"]',
        wait: Capybara.default_max_wait_time,
      )

      composer.submit

      expect(find("#topic-title")).to have_content("Video upload test")

      selector = topic.post_by_number_selector(1)

      expect(page).to have_css(selector)
      within(selector) do
        expect(page).to have_css(".video-placeholder-container[data-thumbnail-src]")
      end
    end

    it "shows video player in composer" do
      SiteSetting.enable_diffhtml_preview = true

      visit "/new-topic"
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.mp4", "media").path
      attach_file(file_path_1) { composer.click_toolbar_button("upload") }

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".video-container video")

      expect(page).to have_css(
        ".video-container video source[src]",
        visible: false,
        wait: Capybara.default_max_wait_time,
      )
    end
  end
end
