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
      SystemMessage.any_instance.expects(:create).with('welcome_invite', {})
      Jobs::SendSystemMessage.new.execute(user_id: user.id, message_type: 'welcome_invite')
    end

    it "can send message parameters" do
      options = { url: "/t/no-spammers-please/123", edit_delay: 5, flag_reason: "Flagged by community" }
      SystemMessage.any_instance.expects(:create).with('post_hidden', options)
      Jobs::SendSystemMessage.new.execute(user_id: user.id, message_type: 'post_hidden', message_options: options)
    end

  end

end
