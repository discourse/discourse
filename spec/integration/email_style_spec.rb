# frozen_string_literal: true

RSpec.describe EmailStyle do
  describe "ERB evaluation" do
    it "does not evaluate ERB outside of the email itself" do
      SiteSetting.email_custom_template = "<hello>%{email_content}</hello><%= (111 * 333) %>"
      html = Email::Renderer.new(UserNotifications.signup(Fabricate(:user))).html
      expect(html).not_to include("36963")
      expect(html).to include("<hello>")
    end
  end

  context "with a custom template" do
    before do
      SiteSetting.email_custom_template = "<body><h1>FOR YOU</h1><div>%{email_content}</div></body>"
      SiteSetting.email_custom_css = "h1 { color: red; } div.body { color: #FAB; }"
      SiteSetting.email_custom_css_compiled = SiteSetting.email_custom_css
    end

    after do
      SiteSetting.remove_override!(:email_custom_template)
      SiteSetting.remove_override!(:email_custom_css)
    end

    context "with invite" do
      subject(:mail_html) { Email::Renderer.new(invite_mail).html }

      fab!(:invite)

      let(:invite_mail) { InviteMailer.send_invite(invite) }

      it "applies customizations" do
        expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
        expect(mail_html).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
      end

      it "applies customizations if compiled is missing" do
        SiteSetting.remove_override!(:email_custom_css_compiled)
        expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
        expect(mail_html).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
      end

      it "can apply RTL attrs" do
        SiteSetting.default_locale = "he"
        body_attrs = mail_html.match(/<body ([^>])+/)
        expect(body_attrs[0]&.downcase).to match(/text-align:\s*right/)
        expect(body_attrs[0]&.downcase).to include('dir="rtl"')
      end
    end

    context "when user_replied" do
      subject(:mail_html) { Email::Renderer.new(mail).html }

      let(:response_by_user) { Fabricate(:user, name: "John Doe") }
      let(:category) { Fabricate(:category, name: "India") }
      let(:topic) { Fabricate(:topic, category: category, title: "Super cool topic") }
      let(:post) { Fabricate(:post, topic: topic, raw: "This is My super duper cool topic") }
      let(:response) { Fabricate(:basic_reply, topic: post.topic, user: response_by_user) }
      let(:user) { Fabricate(:user) }
      let(:notification) { Fabricate(:replied_notification, user: user, post: response) }

      let(:mail) do
        UserNotifications.user_replied(
          user,
          post: response,
          notification_type: notification.notification_type,
          notification_data_hash: notification.data_hash,
        )
      end

      it "customizations are applied to html part of emails" do
        SiteSetting.default_email_in_reply_to = true

        expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
        matches = mail_html.match(/<div style="([^"]+)" dm=\"body\">#{post.raw}/)
        expect(matches[1]).to include("color:#FAB") # custom
        expect(matches[1]).to include("padding-top:5px") # div.body
      end

      # TODO: translation override
    end

    context "with signup" do
      subject(:mail_html) { Email::Renderer.new(signup_mail).html }

      let(:signup_mail) { UserNotifications.signup(Fabricate(:user)) }

      it "customizations are applied to html part of emails" do
        expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
        expect(mail_html).to include("activate-account")
      end

      context "with translation override" do
        before do
          TranslationOverride.upsert!(
            SiteSetting.default_locale,
            "user_notifications.signup.text_body_template",
            "CLICK THAT LINK: %{base_url}/u/activate-account/%{email_token}",
          )
        end

        after do
          TranslationOverride.revert!(
            SiteSetting.default_locale,
            ["user_notifications.signup.text_body_template"],
          )
        end

        it "applies customizations when translation override exists" do
          expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
          expect(mail_html.scan("CLICK THAT LINK").count).to eq(1)
        end
      end

      context "with some bad css" do
        before do
          SiteSetting.email_custom_css = '@import "nope.css"; h1 {{{ size: really big; '
          SiteSetting.email_custom_css_compiled = SiteSetting.email_custom_css
        end

        it "can render the html" do
          expect(mail_html.scan(/<h1\s*(?:style=""){0,1}>FOR YOU<\/h1>/).count).to eq(1)
          expect(mail_html).to include("activate-account")
        end
      end
    end

    context "with digest" do
      subject(:mail_html) { Email::Renderer.new(summary_email).html }

      fab!(:popular_topic) do
        Fabricate(:topic, user: Fabricate(:coding_horror), created_at: 1.hour.ago)
      end

      let(:summary_email) { UserNotifications.digest(Fabricate(:user)) }

      it "customizations are applied to html part of emails" do
        expect(mail_html.scan('<h1 style="color:red">FOR YOU</h1>').count).to eq(1)
        expect(mail_html).to include(popular_topic.title)
      end

      it "doesn't apply customizations if apply_custom_styles_to_digest is disabled" do
        SiteSetting.apply_custom_styles_to_digest = false
        expect(mail_html).to_not include('<h1 style="color:red">FOR YOU</h1>')
        expect(mail_html).to_not include("FOR YOU")
        expect(mail_html).to include(popular_topic.title)
      end
    end
  end
end
