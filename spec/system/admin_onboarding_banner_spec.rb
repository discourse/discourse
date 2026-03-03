# frozen_string_literal: true

describe "Admin Onboarding Banner", type: :system do
  fab!(:admin)

  let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
  let(:predefined_topics_modal) { PageObjects::Modals::AdminOnboardingPredefinedTopics.new }
  let(:create_invite_modal) { PageObjects::Modals::CreateInvite.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_site_owner_onboarding = true

    sign_in(admin)
  end

  describe "banner visibility" do
    it "shows the onboarding banner for admin users" do
      visit("/")
      expect(banner).to be_visible
    end

    it "shows all three onboarding steps" do
      visit("/")
      expect(banner.step("start_posting")).to be_present
      expect(banner.step("invite_collaborators")).to be_present
      expect(banner.step("spread_the_word")).to be_present
    end

    it "can close the banner prematurely" do
      visit("/")
      expect(banner).to be_visible

      banner.close

      expect(toasts).to have_success(I18n.t("js.admin_onboarding_banner.skipped"))

      expect(SiteSetting.enable_site_owner_onboarding).to eq(false)
    end
  end

  describe "start posting step" do
    it "opens composer with selected topic and marks step as complete when topic is created" do
      visit("/")
      expect(banner.step_not_completed?("start_posting")).to eq(true)

      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open
      expect(predefined_topics_modal.topic_card_count).to eq(4)

      predefined_topics_modal.select_topic(0)

      expect(composer).to be_opened
      expect(composer.composer_input.value).not_to be_empty

      composer.composer_input.set("Testing topic selection")
      composer.create
      expect(page).to have_content("Testing topic selection")

      visit("/")
      expect(banner.step_completed?("start_posting")).to eq(true)
    end

    it "can cancel topic selection without completing step" do
      visit("/")
      banner.click_step_action("start_posting")
      expect(predefined_topics_modal).to be_open

      predefined_topics_modal.cancel

      expect(predefined_topics_modal).to be_closed
      expect(banner.step_not_completed?("start_posting")).to eq(true)
    end
  end

  describe "invite collaborators step" do
    it "marks step as complete after creating invite" do
      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button

      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)
    end

    it "does not mark step complete if modal is cancelled" do
      visit("/")
      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
      banner.click_step_action("invite_collaborators")

      expect(create_invite_modal).to be_open
      create_invite_modal.close

      expect(banner.step_not_completed?("invite_collaborators")).to eq(true)
    end
  end

  describe "spread the word step" do
    it "copies site URL to clipboard and marks step complete" do
      visit("/")
      expect(banner.step_not_completed?("spread_the_word")).to eq(true)

      banner.click_step_action("spread_the_word")

      expect(banner.step_completed?("spread_the_word")).to eq(true)
      expect(toasts).to have_success(
        I18n.t("js.admin_onboarding_banner.spread_the_word.copied_to_clipboard"),
      )
    end
  end

  describe "completing all steps" do
    it "disables onboarding when all steps are complete" do
      visit("/")

      banner.click_step_action("start_posting")
      predefined_topics_modal.select_topic(0)
      composer.create
      visit("/")

      expect(banner.step_completed?("start_posting")).to eq(true)

      banner.click_step_action("invite_collaborators")
      create_invite_modal.save_button.click
      expect(create_invite_modal).to have_copy_button
      create_invite_modal.close

      expect(banner.step_completed?("invite_collaborators")).to eq(true)

      banner.click_step_action("spread_the_word")

      # banner is hidden after all steps are complete; No need to check for `spread_the_word` step completion

      expect(banner).to be_not_visible
      expect(SiteSetting.enable_site_owner_onboarding).to eq(false)
    end
  end

  describe "when user is not an admin" do
    fab!(:regular_user, :user)

    it "does not show the banner" do
      sign_in(regular_user)
      visit("/")

      expect(banner).to be_not_visible
    end
  end

  describe "when setting is disabled" do
    before { SiteSetting.enable_site_owner_onboarding = false }

    it "does not show the banner" do
      visit("/")

      expect(banner).to be_not_visible
    end
  end
end
