require 'spec_helper'
require_dependency 'post_destroyer'

describe PostAlertObserver do

  before do
    ActiveRecord::Base.observers.enable :post_alert_observer
  end

  let!(:evil_trout) { Fabricate(:evil_trout) }
  let(:post) { Fabricate(:post) }

  context 'liking' do
    context 'when liking a post' do
      it 'creates a notification' do
        lambda {
          PostAction.act(evil_trout, post, PostActionType.types[:like])
        }.should change(Notification, :count).by(1)
      end
    end

    context 'when removing a liked post' do
      before do
        PostAction.act(evil_trout, post, PostActionType.types[:like])
      end

      it 'removes a notification' do
        lambda {
          PostAction.remove_act(evil_trout, post, PostActionType.types[:like])
        }.should change(Notification, :count).by(-1)
      end
    end
  end

  context 'when editing a post' do
    it 'notifies a user of the revision' do
      lambda {
        post.revise(evil_trout, "world is the new body of the message")
      }.should change(post.user.notifications, :count).by(1)
    end
  end

  context 'quotes' do

    it 'notifies a user by username' do
      lambda {
        Fabricate(:post, raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      }.should change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      p1 = Fabricate(:post, raw: '[quote="Evil Trout, post:1"]whatup[/quote]')
      lambda {
        p1.revise(p1.user, '[quote="Evil Trout, post:1"]whatup now?[/quote]')
      }.should_not change(evil_trout.notifications, :count)
    end

    it "doesn't notify the poster" do
      topic = post.topic
      lambda {
        new_post = Fabricate(:post, topic: topic, user: topic.user, raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]')
      }.should_not change(topic.user.notifications, :count).by(1)
    end
  end

  context '@mentions' do

    let(:user) { Fabricate(:user) }
    let(:mention_post) { Fabricate(:post, user: user, raw: 'Hello @eviltrout')}
    let(:topic) { mention_post.topic }

    it 'notifies a user' do
      lambda {
        mention_post
      }.should change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      lambda {
        mention_post.revise(mention_post.user, "New raw content that still mentions @eviltrout")
      }.should_not change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      lambda {
        Fabricate(:post, user: user, raw: 'second post', topic: topic)
      }.should_not change(user.notifications, :count).by(1)
    end

  end


  context 'private message' do
    let(:user) { Fabricate(:user) }
    let(:mention_post) { Fabricate(:post, user: user, raw: 'Hello @eviltrout')}
    let(:topic) { mention_post.topic }

    it "won't notify someone who can't see the post" do
      lambda {
        Guardian.any_instance.expects(:can_see?).with(instance_of(Post)).returns(false)
        mention_post
      }.should_not change(evil_trout.notifications, :count)
    end
  end

  context 'moderator action post' do
    let(:user) { Fabricate(:user) }
    let(:first_post) { Fabricate(:post, user: user, raw: 'A useless post for you.')}
    let(:topic) { first_post.topic }

    it 'should not notify anyone' do
      expect {
        Fabricate(:post, topic: topic, raw: 'This topic is CLOSED', post_type: Post.types[:moderator_action])
      }.to_not change { Notification.count }
    end
  end

end
