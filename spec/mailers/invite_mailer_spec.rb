require "rails_helper"

describe InviteMailer do

  describe "send_invite" do

    context "invite to site" do
      let(:invite) { Fabricate(:invite) }

      context "default invite message" do
        let(:invite_mail) { InviteMailer.send_invite(invite) }

        it 'renders the invitee email' do
          expect(invite_mail.to).to eql([invite.email])
        end

        it 'renders the subject' do
          expect(invite_mail.subject).to be_present
        end

        it 'renders site domain name in subject' do
          expect(invite_mail.subject).to match(Discourse.current_hostname)
        end

        it 'renders the body' do
          expect(invite_mail.body).to be_present
        end

        it 'renders the inviter email' do
          expect(invite_mail.from).to eql([SiteSetting.notification_email])
        end

        it 'renders invite link' do
          expect(invite_mail.body.encoded).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
        end
      end

      context "custom invite message" do

        context "custom message includes invite link" do
          let(:custom_invite_mail) { InviteMailer.send_invite(invite, "Hello,\n\nYou've been invited you to join\n\n<a href=\"javascript:alert('HACK!')\">Click me.</a>\n\n> **{site_title}**\n>\n> {site_description}\n\nIf you're interested, click the link below:\n\n{invite_link}\n\nThis invitation is from a trusted user, so you won't need to log in.") }

          it 'renders the invitee email' do
            expect(custom_invite_mail.to).to eql([invite.email])
          end

          it 'renders the subject' do
            expect(custom_invite_mail.subject).to be_present
          end

          it 'renders site domain name in subject' do
            expect(custom_invite_mail.subject).to match(Discourse.current_hostname)
          end

          it 'renders the html' do
            expect(custom_invite_mail.html_part).to be_present
          end

          it 'renders custom_message' do
            expect(custom_invite_mail.html_part.to_s).to match("You've been invited you to join")
          end

          it 'renders the inviter email' do
            expect(custom_invite_mail.from).to eql([SiteSetting.notification_email])
          end

          it 'sanitizes HTML' do
            expect(custom_invite_mail.html_part.to_s).to_not match("HACK!")
          end

          it 'renders invite link' do
            expect(custom_invite_mail.html_part.to_s).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
          end
        end

        context "custom message does not include invite link" do
          let(:custom_invite_without_link) { InviteMailer.send_invite(invite, "Hello,\n\nYou've been invited you to join\n\n> **{site_title}**\n>\n> {site_description}") }

          it 'renders default body' do
            expect(custom_invite_without_link.body).to be_present
          end

          it 'does not render html' do
            expect(custom_invite_without_link.html_part).to eq(nil)
          end

          it 'renders invite link' do
            expect(custom_invite_without_link.body.encoded).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
          end
        end
      end
    end

    context "invite to topic" do
      let(:topic) { Fabricate(:topic, excerpt: "Topic invite support is now available in Discourse!") }
      let(:invite) { topic.invite(topic.user, 'name@example.com') }
      let(:invite_mail) { InviteMailer.send_invite(invite) }

      it 'renders the invitee email' do
        expect(invite_mail.to).to eql(['name@example.com'])
      end

      it 'renders the subject' do
        expect(invite_mail.subject).to be_present
      end

      it 'renders topic title in subject' do
        expect(invite_mail.subject).to match(topic.title)
      end

      it 'renders site domain name in subject' do
        expect(invite_mail.subject).to match(Discourse.current_hostname)
      end

      it 'renders the body' do
        expect(invite_mail.body).to be_present
      end

      it 'renders the inviter email' do
        expect(invite_mail.from).to eql([SiteSetting.notification_email])
      end

      it 'renders invite link' do
        expect(invite_mail.body.encoded).to match("#{Discourse.base_url}/invites/#{invite.invite_key}")
      end

      it 'renders topic title' do
        expect(invite_mail.body.encoded).to match(topic.title)
      end
    end

  end

end
