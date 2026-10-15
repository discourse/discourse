# frozen_string_literal: true

describe "Staff writes only mode" do
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

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.staff_writes_only_mode.enabled")),
        useInnerText: true,
      )

      browser_page.goto("/new-topic").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(composer).to be_opened

      title = "Test topic from moderator"
      body = "This is a test post created by a moderator during staff writes only mode."

      composer.fill_title(title)
      composer.fill_content(body)

      composer.create

      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(title),
        useInnerText: true,
      )
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(body),
        useInnerText: true,
      )
    end
  end

  context "when regular user" do
    before { EmailToken.confirm(Fabricate(:email_token, user:).token) }

    it "cannot login during staff writes only mode" do
      login_form.open.fill(username: user.username, password:).click_login

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator("input#login-account-name").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "can view topics but sees staff only mode message when not logged in" do
      browser_page.goto(topic.url).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(topic.title),
        useInnerText: true,
      )
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(post.raw),
        useInnerText: true,
      )
      expect(browser_content).to PlaywrightMatchers.contain_text(
        browser_text_pattern(I18n.t("js.staff_writes_only_mode.enabled_anonymous")),
        useInnerText: true,
      )
      expect(
        browser_root.locator(".login-button").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".sign-up-button").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end
  end
end
