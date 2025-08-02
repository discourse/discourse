# frozen_string_literal: true

describe "Staff writes only mode", type: :system do
  password = SecureRandom.alphanumeric(20)

  fab!(:moderator) { Fabricate(:moderator, password:) }
  fab!(:user) { Fabricate(:user, password:) }
  fab!(:topic) { Fabricate(:topic, user:) }
  fab!(:post) { Fabricate(:post, topic:, user:) }

  let(:login_form) { PageObjects::Pages::Login.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before { Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY) }

  context "when moderator" do
    before { EmailToken.confirm(Fabricate(:email_token, user: moderator).token) }

    it "can login and post during staff writes only mode" do
      login_form.open.fill(username: moderator.username, password:).click_login

      expect(page).to have_css(".header-dropdown-toggle.current-user")

      page.visit "/new-topic"

      expect(composer).to be_opened

      title = "Test topic from moderator"
      body = "This is a test post created by a moderator during staff writes only mode."

      composer.fill_title(title)
      composer.fill_content(body)

      composer.create

      expect(page).to have_content(title)
      expect(page).to have_content(body)
    end
  end

  context "when regular user" do
    before { EmailToken.confirm(Fabricate(:email_token, user:).token) }

    it "cannot login during staff writes only mode" do
      login_form.open.fill(username: user.username, password:).click_login

      expect(page).not_to have_css(".header-dropdown-toggle.current-user")
      expect(page).to have_css("input#login-account-name")
    end

    it "can view topics but sees staff only mode message when not logged in" do
      page.visit topic.url

      expect(page).to have_content(topic.title)
      expect(page).to have_content(post.raw)
      expect(page).to have_content(I18n.t("js.staff_writes_only_mode.enabled"))
    end
  end
end
