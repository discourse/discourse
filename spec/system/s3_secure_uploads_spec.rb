# frozen_string_literal: true

describe "Uploading files in the composer to S3", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:other_user) { Fabricate(:user, username: "otherguy") }

  let(:modal) { PageObjects::Modals::Base.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  describe "secure uploads" do
    def first_post_img(wait: Capybara.default_max_wait_time)
      first_post = topic_page.post_by_number(1, wait: wait)
      expect(first_post).to have_css("img[data-base62-sha1]")
      first_post.find(".cooked").first("img")
    end

    def expect_first_post_to_have_secure_upload
      img = first_post_img
      expect(img["src"]).to include("/secure-uploads")
      topic = topic_page.current_topic
      expect(topic.first_post.uploads.first.secure).to eq(true)
    end

    it "marks uploads inside of private message posts as secure" do
      setup_or_skip_s3_system_test(enable_secure_uploads: true)
      sign_in(current_user)

      topic_page.open_new_message

      composer.fill_title("This is a test PM for secure uploads")
      composer.select_pm_user("otherguy")

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) { composer.click_toolbar_button("upload") }

      expect(page).to have_no_css("#file-uploading")
      expect(composer.preview).to have_css(".image-wrapper")

      composer.submit

      expect_first_post_to_have_secure_upload
    end

    it "marks uploads inside of private category posts as secure" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      setup_or_skip_s3_system_test(enable_secure_uploads: true)
      sign_in(current_user)

      topic_page.open_new_topic

      composer.fill_title("This is a test PM for secure uploads")
      composer.switch_category(private_category.name)

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) { composer.click_toolbar_button("upload") }

      expect(page).to have_no_css("#file-uploading")
      expect(composer.preview).to have_css(".image-wrapper")

      composer.submit

      expect_first_post_to_have_secure_upload
    end

    it "marks uploads for all posts as secure when login_required" do
      SiteSetting.login_required = true
      setup_or_skip_s3_system_test(enable_secure_uploads: true)
      sign_in(current_user)

      topic_page.open_new_topic

      composer.fill_title("This is a test PM for secure uploads")

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) { composer.click_toolbar_button("upload") }

      expect(page).to have_no_css("#file-uploading")
      expect(composer.preview).to have_css(".image-wrapper")

      composer.submit

      expect_first_post_to_have_secure_upload
    end

    it "doesn't mark uploads for public posts as secure" do
      setup_or_skip_s3_system_test(enable_secure_uploads: true)
      sign_in(current_user)

      topic_page.open_new_topic

      composer.fill_title("This is a test PM for secure uploads")

      file_path = file_from_fixtures("logo.png", "images").path
      attach_file(file_path) { composer.click_toolbar_button("upload") }

      expect(page).to have_no_css("#file-uploading")
      expect(composer.preview).to have_css(".image-wrapper")

      Jobs.run_immediately!
      composer.submit

      # Extra wait time is added because the job can slow down the processing of the request.
      img = first_post_img(wait: 10)

      # At first the image will be secure when created via the composer, usually the
      # CookedPostProcessor job fixes this but running it immediately when creating the
      # post doesn't work in the test, so we need to rebake here to get the correct result.
      expect(page).to have_css("img[src*='secure-uploads']")
      Post.last.rebake!
      expect(page).not_to have_css("img[src*='secure-uploads']", wait: 5)
      topic = topic_page.current_topic
      expect(topic.first_post.uploads.first.secure).to eq(false)
    end
  end
end
