# frozen_string_literal: true

require 'rails_helper'

describe Jobs::InviteEmail do

  context '.execute' do

    it 'raises an error when the invite_id is missing' do
      expect { Jobs::InviteEmail.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
    end

    context 'with an invite id' do

      let (:mailer) { Mail::Message.new(to: 'eviltrout@test.domain') }
      fab!(:invite) { Fabricate(:invite) }

      it 'delegates to the test mailer' do
        Email::Sender.any_instance.expects(:send)
        InviteMailer.expects(:send_invite).with(invite, nil).returns(mailer)
        Jobs::InviteEmail.new.execute(invite_id: invite.id)
      end

      it "aborts without error when the invite doesn't exist anymore" do
        invite.destroy
        InviteMailer.expects(:send_invite).never
        Jobs::InviteEmail.new.execute(invite_id: invite.id)
      end

      it "updates invite emailed_status" do
        invite.emailed_status = Invite.emailed_status_types[:pending]
        invite.save!
        Jobs::InviteEmail.new.execute(invite_id: invite.id)

        invite.reload
        expect(invite.emailed_status).to eq(Invite.emailed_status_types[:sent])
      end
    end
  end
end
