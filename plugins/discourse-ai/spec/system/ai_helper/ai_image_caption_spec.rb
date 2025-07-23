# frozen_string_literal: true

RSpec.describe "AI image caption", type: :system, js: true do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:non_member_group) { Fabricate(:group) }
  let(:user_preferences_ai_page) { PageObjects::Pages::UserPreferencesAi.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:popup) { PageObjects::Components::AiCaptionPopup.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:file_path) { plugin_file_from_fixtures("100x100.jpg").path }
  let(:captioned_image_path) do
    plugin_file_from_fixtures("An image of discobot in action.png").path
  end
  let(:caption) do
    "The image shows a stylized speech bubble icon with a multicolored border on a black background."
  end
  let(:caption_with_attrs) do
    "#{caption} (#{I18n.t("discourse_ai.ai_helper.image_caption.attribution")})"
  end

  before do
    enable_current_plugin
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_helper_model)
    assign_fake_provider_to(:ai_helper_image_caption_model)
    SiteSetting.ai_helper_enabled = true
    SiteSetting.ai_helper_enabled_features = "image_caption"
    sign_in(user)
  end

  shared_examples "shows no image caption button" do
    it "should not show an image caption button" do
      visit("/latest")
      page.find("#create-topic").click
      attach_file([file_path]) { composer.click_toolbar_button("upload") }
      wait_for { composer.has_no_in_progress_uploads? }
      expect(popup).to have_no_generate_caption_button
    end
  end

  context "when not a member of ai helper group" do
    before { SiteSetting.composer_ai_helper_allowed_groups = non_member_group.id.to_s }
    include_examples "shows no image caption button"
  end

  context "when image caption feature is disabled" do
    before { SiteSetting.ai_helper_enabled_features = "" }
    include_examples "shows no image caption button"
  end

  context "when triggering caption with AI on desktop" do
    it "should show an image caption in an input field" do
      DiscourseAi::Completions::Llm.with_prepared_responses([caption]) do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { composer.click_toolbar_button("upload") }
        popup.click_generate_caption
        expect(popup.has_caption_popup_value?(caption_with_attrs)).to eq(true)
        popup.save_caption
        wait_for { page.find(".image-wrapper img")["alt"] == caption_with_attrs }
        expect(page.find(".image-wrapper img")["alt"]).to eq(caption_with_attrs)
      end
    end

    it "should allow you to cancel a caption request" do
      DiscourseAi::Completions::Llm.with_prepared_responses([caption]) do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { composer.click_toolbar_button("upload") }
        popup.click_generate_caption
        popup.cancel_caption
        expect(popup).to have_no_disabled_generate_button
      end
    end
  end

  context "when triggering caption with AI on mobile", mobile: true do
    it "should show update the image alt text with the caption" do
      DiscourseAi::Completions::Llm.with_prepared_responses([caption]) do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { page.find(".mobile-file-upload").click }
        page.find(".mobile-preview").click
        popup.click_generate_caption
        wait_for { page.find(".image-wrapper img")["alt"] == caption_with_attrs }
        expect(page.find(".image-wrapper img")["alt"]).to eq(caption_with_attrs)
      end
    end
  end

  describe "automatic image captioning" do
    context "when the user preference is disabled" do
      before { user.user_option.update!(auto_image_caption: false) }

      it "should show a prompt when submitting a post with captionable images uploaded" do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([file_path]) { composer.click_toolbar_button("upload") }
        wait_for { composer.has_no_in_progress_uploads? }
        composer.fill_title("I love using Discourse! It is my favorite forum software")
        composer.create
        expect(dialog).to be_open
      end

      it "should not show a prompt when submitting a post with no captionable images uploaded" do
        visit("/latest")
        page.find("#create-topic").click
        attach_file([captioned_image_path]) { composer.click_toolbar_button("upload") }
        wait_for { composer.has_no_in_progress_uploads? }
        composer.fill_title("I love using Discourse! It is my favorite forum software")
        composer.create
        expect(dialog).to be_closed
      end

      it "should auto caption the existing images and update the preference when dialog is accepted" do
        DiscourseAi::Completions::Llm.with_prepared_responses([caption]) do
          visit("/latest")
          page.find("#create-topic").click
          attach_file([file_path]) { composer.click_toolbar_button("upload") }
          wait_for { composer.has_no_in_progress_uploads? }
          composer.fill_title("I love using Discourse! It is my favorite forum software")
          composer.create
          dialog.click_yes
          wait_for(timeout: 100) { page.find("#post_1 .cooked img")["alt"] == caption_with_attrs }
          expect(page.find("#post_1 .cooked img")["alt"]).to eq(caption_with_attrs)
        end
      end
    end

    context "when a post has no uploads" do
      before { user.user_option.update!(auto_image_caption: true) }

      it "should create the topic without triggering auto caption" do
        title = "I love using Discourse! It is my favorite forum software"
        visit("/latest")
        page.find("#create-topic").click
        composer.fill_title(title)
        composer.fill_content(
          "Culpa labore velit cupidatat commodo magna esse et minim consequat veniam dolore eiusmod. Labore eu elit in nulla ipsum elit consectetur sunt consectetur enim. Cillum ex ex velit eiusmod labore ullamco ut ad. Dolore dolor commodo nisi fugiat esse quis anim officia quis. Pariatur cillum pariatur irure cupidatat nostrud ullamco labore id aliqua ut nostrud. Eu adipisicing ut laboris.",
        )
        composer.create
        expect(dialog).to be_closed
        expect(topic_page).to have_topic_title(title)
      end

      it "should create a reply to a post without triggering auto caption" do
        visit("/t/-/#{topic.id}")
        topic_page.click_footer_reply
        composer.fill_content(
          "Culpa labore velit cupidatat commodo magna esse et minim consequat veniam dolore eiusmod. Labore eu elit in nulla ipsum elit consectetur sunt consectetur enim. Cillum ex ex velit eiusmod labore ullamco ut ad. Dolore dolor commodo nisi fugiat esse quis anim officia quis. Pariatur cillum pariatur irure cupidatat nostrud ullamco labore id aliqua ut nostrud. Eu adipisicing ut laboris.",
        )
        composer.create
        expect(dialog).to be_closed
        expect(topic_page).to have_post_number(post.post_number)
      end
    end
  end
end
