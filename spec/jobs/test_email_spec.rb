require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::TestEmail do

  context '.execute' do
    it 'raises an error when the address is missing' do
      expect { Jobs::TestEmail.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
    end

    context 'with an address' do

      let (:mailer) { Mail::Message.new(to: 'eviltrout@test.domain') }

      it 'delegates to the test mailer' do
        Email::Sender.any_instance.expects(:send)
        TestMailer.expects(:send_test).with('eviltrout@test.domain').returns(mailer)
        Jobs::TestEmail.new.execute(to_address: 'eviltrout@test.domain')
      end

    end

  end

end
