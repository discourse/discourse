require "rails_helper"

describe InviteMailer do

  describe "send_invite" do

    context "invite to site" do
      let(:invite) { Fabricate(:invite) }
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
