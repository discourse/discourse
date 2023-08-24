# frozen_string_literal: true

describe "Uploading files in the composer", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic) { PageObjects::Pages::Topic.new }

  before { sign_in(current_user) }

  it "uploads multiple files at once" do
    sign_in(current_user)

    visit "/new-topic"
    expect(composer).to be_opened

    file_path_1 = file_from_fixtures("logo.png", "images").path
    file_path_2 = file_from_fixtures("logo.jpg", "images").path
    attach_file([file_path_1, file_path_2]) { composer.click_toolbar_button("upload") }

    expect(composer).to have_no_in_progress_uploads
    expect(composer.preview).to have_css(".image-wrapper", count: 2)
  end

  it "allows cancelling uploads" do
    sign_in(current_user)

    visit "/new-topic"
    expect(composer).to be_opened

    page.driver.browser.network_conditions = { latency: 20_000 }

    file_path_1 = file_from_fixtures("logo.png", "images").path
    attach_file(file_path_1) { composer.click_toolbar_button("upload") }
    expect(composer).to have_in_progress_uploads
    find("#cancel-file-upload").click

    expect(composer).to have_no_in_progress_uploads
    expect(composer.preview).to have_no_css(".image-wrapper")
  ensure
    page.driver.browser.network_conditions = { latency: 0 }
  end

  context "when video thumbnails are enabled" do
    before do
      SiteSetting.video_thumbnails_enabled = true
      SiteSetting.authorized_extensions += "|mp4"
    end

    # TODO (martin): Video streaming is not yet available in Chrome for Testing,
    # we need to come back to this in a few months and try again.
    #
    # c.f. https://groups.google.com/g/chromedriver-users/c/1SMbByMfO2U
    xit "generates a thumbnail for the video" do
      sign_in(current_user)

      visit "/new-topic"
      expect(composer).to be_opened
      topic.fill_in_composer_title("Video upload test")

      file_path_1 = file_from_fixtures("small.mp4", "media").path
      attach_file(file_path_1) { composer.click_toolbar_button("upload") }

      expect(composer).to have_no_in_progress_uploads
      expect(composer.preview).to have_css(".video-container")

      composer.submit

      expect(find("#topic-title")).to have_content("Video upload test")
      expect(topic.image_upload_id).to eq(Upload.last.id)
    end
  end
end
