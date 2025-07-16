# frozen_string_literal: true

describe PostSerializer do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  context "when post has an event" do
    let(:user) { Fabricate(:user, admin: true) }
    let(:topic_1) { Fabricate(:topic, user: user) }
    let(:post_1) { Fabricate(:post, topic: topic_1) }
    let!(:post_event_1) { Fabricate(:event, post: post_1) }

    it "serializes the associated event" do
      json = PostSerializer.new(post_1, scope: Guardian.new).as_json
      expect(json[:post][:event]).to be_present
    end

    context "when the post has been destroyed" do
      before { PostDestroyer.new(Discourse.system_user, post_1).destroy }

      it "doesn’t serialize the associated event" do
        json = PostSerializer.new(post_1, scope: Guardian.new).as_json
        expect(json[:post][:event]).to_not be_present
      end
    end
  end
end
