# frozen_string_literal: true

RSpec.describe "Email theme header and footer" do
  def create_theme_with_email_fields
    theme = Fabricate(:theme)
    theme.set_field(
      target: :email,
      name: "header",
      value: "<div class='email-header'>%{header_branding}</div>",
    )
    theme.set_field(
      target: :email,
      name: "footer",
      value:
        "<div class='email-footer'>%{footer_text} <a href='%{unsubscribe_url}'>%{unsubscribe_link}</a> %{typo_key}</div>",
    )
    theme.set_field(target: :translations, name: :en, value: <<~YAML)
        en:
          header_branding: "ACME Corp"
          footer_text: "All rights reserved"
          unsubscribe_link: "Unsubscribe"
      YAML
    theme.set_field(target: :translations, name: :fr, value: <<~YAML)
        fr:
          footer_text: "Tous droits réservés"
          unsubscribe_link: "Se désinscrire"
      YAML
    theme.save!
    theme
  end

  fab!(:theme) { create_theme_with_email_fields }
  before do
    SiteSetting.default_theme_id = theme.id
    SiteSetting.enable_email_theme_header_and_footer = true
  end

  context "with signup email" do
    subject(:mail_renderer) { Email::Renderer.new(signup_mail) }

    fab!(:user)

    let(:signup_mail) { UserNotifications.signup(user) }

    it "renders the theme header and footer with translated strings in both formats" do
      expect(mail_renderer.html).to include("ACME Corp", "All rights reserved", "Unsubscribe")
      expect(mail_renderer.html).to include("activate-account")
      expect(mail_renderer.text).to include("ACME Corp", "All rights reserved", "Unsubscribe")
      expect(mail_renderer.text).not_to include("<div class='email-header'>")
    end

    it "omits theme fragments when they are disabled" do
      SiteSetting.enable_email_theme_header_and_footer = false

      expect(mail_renderer.html).to include("activate-account")
      expect(mail_renderer.html).not_to include("ACME Corp", "All rights reserved")
      expect(mail_renderer.text).to include("activate-account")
      expect(mail_renderer.text).not_to include("ACME Corp", "All rights reserved")
    end

    it "falls back to the preferences URL when no unsubscribe link is available" do
      expect(mail_renderer.html).to include("#{Discourse.base_url}/my/preferences")
      expect(mail_renderer.text).to include("#{Discourse.base_url}/my/preferences")
    end

    it "places theme fragments using explicit email-style placeholders" do
      SiteSetting.email_custom_template = <<~HTML
        <html>
          <body>
            <div id="footer-slot">%{theme_email_footer}</div>
            <main>%{email_content}</main>
            <div id="header-slot">%{theme_email_header}</div>
          </body>
        </html>
      HTML

      document = Nokogiri::HTML5.parse(mail_renderer.html)

      expect(document.at_css("#header-slot .email-header").text).to eq("ACME Corp")
      expect(document.at_css("#footer-slot .email-footer").text).to include("All rights reserved")
      expect(document.at_css("main").to_html).to include("activate-account")
      expect(document.at_css("main .email-header, main .email-footer")).to be_nil
    end

    it "wraps the email content for legacy email-style templates" do
      SiteSetting.email_custom_template =
        '<html><body><main id="legacy-content">%{email_content}</main></body></html>'

      document = Nokogiri::HTML5.parse(mail_renderer.html)

      expect(document.at_css("#legacy-content .email-header").text).to eq("ACME Corp")
      expect(document.at_css("#legacy-content .email-footer").text).to include(
        "All rights reserved",
      )
      expect(document.at_css("#legacy-content").to_html).to include("activate-account")
    end

    it "allows an explicit email-style template to omit a theme fragment" do
      SiteSetting.email_custom_template =
        "<html><body>%{theme_email_header}<main>%{email_content}</main></body></html>"

      rendered_html = mail_renderer.html

      expect(rendered_html).to include("ACME Corp", "activate-account")
      expect(rendered_html).not_to include("All rights reserved")
    end

    it "leaves unknown translation keys untouched" do
      expect(mail_renderer.html).to include("%{typo_key}")
      expect(mail_renderer.text).to include("%{typo_key}")
    end

    it "does not render the header or footer without a default theme" do
      SiteSetting.default_theme_id = -1
      expect(mail_renderer.html).not_to include("ACME Corp", "All rights reserved")
      expect(mail_renderer.text).not_to include("ACME Corp", "All rights reserved")
    end
  end

  context "with notification email" do
    subject(:mail_renderer) { Email::Renderer.new(mail) }

    fab!(:response_by_user) { Fabricate(:user, name: "John Doe") }
    fab!(:topic) { Fabricate(:topic, title: "Super cool topic") }
    fab!(:post) { Fabricate(:post, topic: topic, raw: "This is my super duper cool topic") }
    fab!(:response) { Fabricate(:basic_reply, topic: post.topic, user: response_by_user) }
    fab!(:user)
    fab!(:notification) { Fabricate(:replied_notification, user: user, post: response) }

    let(:mail) do
      UserNotifications.user_replied(
        user,
        post: response,
        notification_type: notification.notification_type,
        notification_data_hash: notification.data_hash,
      )
    end

    it "uses the per-recipient topic unsubscribe key for %{unsubscribe_url}" do
      list_unsubscribe = mail.header["List-Unsubscribe"].value.match(/<([^>]+)>/)[1]
      expect(mail_renderer.html).to include(list_unsubscribe, "/email/unsubscribe/")
      expect(mail_renderer.text).to include(list_unsubscribe, "/email/unsubscribe/")
    end
  end

  context "with digest email" do
    subject(:mail_renderer) { Email::Renderer.new(summary_email, locale: user.effective_locale) }

    fab!(:popular_topic) do
      Fabricate(:topic, user: Fabricate(:coding_horror), created_at: 1.hour.ago)
    end

    fab!(:user)

    let(:summary_email) { UserNotifications.digest(user) }

    it "uses the digest unsubscribe key for %{unsubscribe_url}" do
      expect(mail_renderer.html).to include("All rights reserved")
      expect(mail_renderer.html).to match(%r{/email/unsubscribe/[a-f0-9]{64}})
      expect(mail_renderer.text).to include("All rights reserved")
      expect(mail_renderer.text).to match(%r{/email/unsubscribe/[a-f0-9]{64}})
    end

    it "uses the preferences URL when unsubscribe links are skipped" do
      rendered_contents = nil

      expect do
        renderer = Email::Renderer.new(UserNotifications.digest(user, skip_unsubscribe_links: true))
        rendered_contents = [renderer.html, renderer.text]
      end.not_to change { UnsubscribeKey.count }

      expect(rendered_contents).to all(include("#{Discourse.base_url}/my/preferences"))
      rendered_contents.each do |rendered_content|
        expect(rendered_content).not_to include("/email/unsubscribe/")
      end
    end

    it "renders the footer when custom email styles are disabled" do
      SiteSetting.apply_custom_styles_to_digest = false
      expect(mail_renderer.html).to include("All rights reserved")
      expect(mail_renderer.html).to match(%r{/email/unsubscribe/[a-f0-9]{64}})
    end

    it "translates the footer in the recipient's locale in both formats" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: "fr")

      expect(mail_renderer.html).to include("Tous droits réservés", "Se désinscrire")
      expect(mail_renderer.html).not_to include("All rights reserved")
      expect(mail_renderer.text).to include("Tous droits réservés", "Se désinscrire")
      expect(mail_renderer.text).not_to include("All rights reserved")
    end
  end

  context "with theme components" do
    subject(:mail_renderer) { Email::Renderer.new(signup_mail) }

    fab!(:user)

    let(:signup_mail) { UserNotifications.signup(user) }

    it "ignores email fragments from attached components" do
      component = Fabricate(:theme, component: true)
      component.set_field(
        target: :email,
        name: "footer",
        value: "<div class='component-footer'>%{component_footer}</div>",
      )
      component.set_field(target: :translations, name: :en, value: <<~YAML)
          en:
            component_footer: "Powered by ACME"
        YAML
      component.save!
      theme.add_relative_theme!(:child, component)

      expect(mail_renderer.html).to include("All rights reserved")
      expect(mail_renderer.html).not_to include("Powered by ACME")
      expect(mail_renderer.text).to include("All rights reserved")
      expect(mail_renderer.text).not_to include("Powered by ACME")
    end
  end
end
