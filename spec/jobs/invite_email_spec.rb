require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::InviteEmail do
  context '.execute' do
    it 'raises an error when the invite_id is missing' do
      expect { Jobs::InviteEmail.new.execute({}) }.to raise_error(
            Discourse::InvalidParameters
          )
    end

    context 'with an invite id' do
      let (:mailer) do
        Mail::Message.new(to: 'eviltrout@test.domain')
      end
      let (:invite) do
        Fabricate(:invite)
      end

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
    end
  end
end
