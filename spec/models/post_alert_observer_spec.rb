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
          # one like (welcome badge deferred)
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
        post.revise(evil_trout, { raw: "world is the new body of the message" })
      }.should change(post.user.notifications, :count).by(1)
    end

    context "edit notifications are disabled" do

      before { SiteSetting.stubs(:disable_edit_notifications).returns(true) }


      it 'notifies a user of the revision made by another user' do
        lambda {
          post.revise(evil_trout, { raw: "world is the new body of the message" })
        }.should change(post.user.notifications, :count).by(1)
      end

      it 'does not notifiy a user of the revision made by the system user' do
        lambda {
          post.revise(Discourse.system_user, { raw: "world is the new body of the message" })
        }.should_not change(post.user.notifications, :count)
      end

    end

  end

  context 'private message' do
    let(:user) { Fabricate(:user) }
    let(:mention_post) { Fabricate(:post, user: user, raw: 'Hello @eviltrout')}
    let(:topic) do
      topic = mention_post.topic
      topic.update_columns archetype: Archetype.private_message, category_id: nil
      topic
    end

    it "won't notify someone who can't see the post" do
      lambda {
        Guardian.any_instance.expects(:can_see?).with(instance_of(Post)).returns(false)
        mention_post
        PostAlerter.new.after_create_post(mention_post)
        PostAlerter.new.after_save_post(mention_post)
      }.should_not change(evil_trout.notifications, :count)
    end

    it 'creates like notifications' do
      other_user = Fabricate(:user)
      topic.allowed_users << user << other_user
      lambda {
        PostAction.act(other_user, mention_post, PostActionType.types[:like])
      }.should change(user.notifications, :count)
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
