# frozen_string_literal: true

RSpec.describe Jobs::PushNotification do
  fab!(:user)
  let(:payload) { { "notification_type" => 1, "excerpt" => "Hello you" } }

  it "delegates to DeliverPushNotification" do
    args = { user_id: user.id, payload: payload }
    Jobs::DeliverPushNotification.any_instance.expects(:execute).with(args)
    Jobs::PushNotification.new.execute(args)
  end
end
