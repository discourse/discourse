require 'rails_helper'
require 'jobs/regular/send_system_message'

describe Jobs::SendSystemMessage do

  it "raises an error without a user_id" do
    expect { Jobs::SendSystemMessage.new.execute(message_type: 'welcome_invite') }.to raise_error(Discourse::InvalidParameters)
  end

  it "raises an error without a message_type" do
    expect { Jobs::SendSystemMessage.new.execute(user_id: 1234) }.to raise_error(Discourse::InvalidParameters)
  end

  context 'with valid parameters' do

    let(:user) { Fabricate(:user) }

    it "should call SystemMessage.create" do
      SystemMessage.any_instance.expects(:create).with('welcome_invite')
      Jobs::SendSystemMessage.new.execute(user_id: user.id, message_type: 'welcome_invite')
    end

  end

end
