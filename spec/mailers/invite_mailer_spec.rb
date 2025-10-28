# frozen_string_literal: true

RSpec.describe InviteMailer do
  describe "send_invite" do
    context "when inviting to site" do
      context "with default invite message" do
        fab!(:invite)
        let(:invite_mail) { InviteMailer.send_invite(invite) }

        it "renders the invitee email" do
          expect(invite_mail.to).to eql([invite.email])
        end

        it "renders the subject" do
          expect(invite_mail.subject).to be_present
        end

        it "renders site domain name in subject" do
          expect(invite_mail.subject).to match(Discourse.current_hostname)
        end

        it "renders the body" do
          expect(invite_mail.body).to be_present
        end

        it "renders the inviter email" do
          expect(invite_mail.from).to eql([SiteSetting.notification_email])
        end

        it "renders invite link" do
          expect(invite_mail.body.encoded).to match(
            "#{Discourse.base_url}/invites/#{invite.invite_key}",
          )
        end
      end

      context "with custom invite message" do
        fab!(:invite) do
          Fabricate(:invite, custom_message: "Hey, you <b>should</b> join this forum!\n\nWelcome!")
        end

        context "when custom message includes invite link" do
          let(:custom_invite_mail) { InviteMailer.send_invite(invite) }

          it "renders the invitee email" do
            expect(custom_invite_mail.to).to eql([invite.email])
          end

          it "renders the subject" do
            expect(custom_invite_mail.subject).to be_present
          end

          it "renders site domain name in subject" do
            expect(custom_invite_mail.subject).to match(Discourse.current_hostname)
          end

          it "renders the body" do
            expect(custom_invite_mail.body).to be_present
          end

          it "renders custom_message, stripping HTML" do
            expect(custom_invite_mail.body.encoded).to match(
              "Hey, you should join this forum! Welcome!",
            )
          end

          it "renders the inviter email" do
            expect(custom_invite_mail.from).to eql([SiteSetting.notification_email])
          end

          it "renders invite link" do
            expect(custom_invite_mail.body.encoded).to match(
              "#{Discourse.base_url}/invites/#{invite.invite_key}",
            )
          end
        end
      end

      # TODO: Very flaky test
      # 1) InviteMailer send_invite when inviting to site with template modifier allows plugins to customize the invite template
      #  Failure/Error: expect(mail.subject).to eq("[Discourse] Custom Invite from Bruce Wayne (bruce0)")

      #    expected: "[Discourse] Custom Invite from Bruce Wayne (bruce0)"
      #         got: "[Discourse] Custom Invite from Bruce Wayne (bruce3)"
      skip "with template modifier" do
        fab!(:invite)
        let(:plugin) { Plugin::Instance.new }
        let(:custom_template) { "plugin_custom_invite_template" }
        I18n.backend.store_translations(
          :en,
          {
            plugin_custom_invite_template: {
              subject_template: "[%{site_name}] Custom Invite from %{inviter_name}",
              text_body_template:
                "Custom invite body: %{invite_link}\n\nFrom: %{inviter_name}\nSite: %{site_domain_name}",
            },
          },
        )
        it "allows plugins to customize the invite template" do
          plugin_instance = Plugin::Instance.new
          @modifier_block = Proc.new { |template, passed_invite| custom_template }

          DiscoursePluginRegistry.register_modifier(
            plugin_instance,
            :invite_forum_mailer_template,
            &@modifier_block
          )

          mail = InviteMailer.send_invite(invite)
          expect(mail.subject).to eq("[Discourse] Custom Invite from Bruce Wayne (bruce0)")

          DiscoursePluginRegistry.unregister_modifier(
            plugin_instance,
            :invite_forum_mailer_template,
            &@modifier_block
          )
        end
      end
    end

    context "when inviting to topic" do
      fab!(:trust_level_2)
      let(:topic) do
        Fabricate(
          :topic,
          excerpt: "Topic invite support is now available in Discourse!",
          user: trust_level_2,
        )
      end

      context "with default invite message" do
        let(:invite) do
          topic.invite(topic.user, "name@example.com")
          Invite.find_by(invited_by_id: topic.user.id)
        end

        let(:invite_mail) { InviteMailer.send_invite(invite, invite_to_topic: true) }

        it "renders the invitee email" do
          expect(invite_mail.to).to eql(["name@example.com"])
        end

        it "renders the subject" do
          expect(invite_mail.subject).to be_present
        end

        it "renders topic title in subject" do
          expect(invite_mail.subject).to match(topic.title)
        end

        it "renders site domain name in subject" do
          expect(invite_mail.subject).to match(Discourse.current_hostname)
        end

        it "renders the body" do
          expect(invite_mail.body).to be_present
        end

        it "renders the inviter email" do
          expect(invite_mail.from).to eql([SiteSetting.notification_email])
        end

        it "renders invite link" do
          expect(invite_mail.body.encoded).to match(
            "#{Discourse.base_url}/invites/#{invite.invite_key}",
          )
        end

        it "renders topic title" do
          expect(invite_mail.body.encoded).to match(topic.title)
        end

        it "respects the private_email setting" do
          SiteSetting.private_email = true

          message = invite_mail
          expect(message.body.to_s).not_to include(topic.title)
          expect(message.body.to_s).not_to include(topic.slug)
        end
      end

      context "with custom invite message" do
        let(:invite) do
          topic.invite(
            topic.user,
            "name@example.com",
            nil,
            "Hey, I thought you might enjoy this topic!",
          )

          Invite.find_by(invited_by_id: topic.user.id)
        end
        let(:custom_invite_mail) { InviteMailer.send_invite(invite) }

        it "renders custom_message" do
          expect(custom_invite_mail.body.encoded).to match(
            "Hey, I thought you might enjoy this topic!",
          )
        end

        it "renders invite link" do
          expect(custom_invite_mail.body.encoded).to match(
            "#{Discourse.base_url}/invites/#{invite.invite_key}",
          )
        end
      end
    end
  end
end
