# frozen_string_literal: true

require "rails_helper"

describe DiscoursePostEvent::Invitee do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, admin: true) }
  let(:user_1) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post1) { Fabricate(:post, topic: topic) }
  let(:post_event) { Fabricate(:event, post: post1) }

  context "when a user is destroyed" do
    context "when the user is an invitee to an event" do
      before { post_event.create_invitees([{ user_id: user_1.id, status: nil }]) }

      it "destroys the invitee" do
        expect(post_event.invitees.first.user.id).to eq(user_1.id)

        UserDestroyer.new(user_1).destroy(user_1)

        expect(post_event.invitees).to be_empty
      end
    end
  end
end
