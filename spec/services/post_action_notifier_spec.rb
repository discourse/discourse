require 'rails_helper'
require_dependency 'post_destroyer'

describe PostActionNotifier do

  before do
    PostActionNotifier.enable
  end

  let!(:evil_trout) { Fabricate(:evil_trout) }
  let(:post) { Fabricate(:post) }

  context 'liking' do
    context 'when liking a post' do
      it 'creates a notification' do
        expect {
          PostAction.act(evil_trout, post, PostActionType.types[:like])
          # one like (welcome badge deferred)
        }.to change(Notification, :count).by(1)
      end
    end

    context 'when removing a liked post' do
      it 'removes a notification' do
        PostAction.act(evil_trout, post, PostActionType.types[:like])
        expect {
          PostAction.remove_act(evil_trout, post, PostActionType.types[:like])
        }.to change(Notification, :count).by(-1)
      end
    end
  end

  context 'when editing a post' do
    it 'notifies a user of the revision' do
      expect {
        post.revise(evil_trout, raw: "world is the new body of the message")
      }.to change(post.user.notifications, :count).by(1)
    end

    context "edit notifications are disabled" do

      before { SiteSetting.disable_edit_notifications = true }

      it 'notifies a user of the revision made by another user' do
        expect {
          post.revise(evil_trout, raw: "world is the new body of the message")
        }.to change(post.user.notifications, :count).by(1)
      end

      it 'does not notifiy a user of the revision made by the system user' do
        expect {
          post.revise(Discourse.system_user, raw: "world is the new body of the message")
        }.not_to change(post.user.notifications, :count)
      end

    end

  end

  context 'private message' do
    let(:user) { Fabricate(:user) }
    let(:mention_post) { Fabricate(:post, user: user, raw: 'Hello @eviltrout') }
    let(:topic) do
      topic = mention_post.topic
      topic.update_columns archetype: Archetype.private_message, category_id: nil
      topic
    end

    it "won't notify someone who can't see the post" do
      expect {
        Guardian.any_instance.expects(:can_see?).with(instance_of(Post)).returns(false)
        mention_post
        PostAlerter.post_created(mention_post)
      }.not_to change(evil_trout.notifications, :count)
    end

    it 'creates like notifications' do
      other_user = Fabricate(:user)
      topic.allowed_users << user << other_user
      expect {
        PostAction.act(other_user, mention_post, PostActionType.types[:like])
      }.to change(user.notifications, :count)
    end
  end

  context 'moderator action post' do
    let(:user) { Fabricate(:user) }
    let(:first_post) { Fabricate(:post, user: user, raw: 'A useless post for you.') }
    let(:topic) { first_post.topic }

    it 'should not notify anyone' do
      expect {
        Fabricate(:post, topic: topic, raw: 'This topic is CLOSED', post_type: Post.types[:moderator_action])
      }.to_not change { Notification.count }
    end
  end

end
