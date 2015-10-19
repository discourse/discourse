require 'spec_helper'

describe PostAlerter do

  let!(:evil_trout) { Fabricate(:evil_trout) }

  def create_post_with_alerts(args={})
    post = Fabricate(:post, args)
    PostAlerter.post_created(post)
  end

  context "unread" do
    it "does not return whispers as unread posts" do
      op = Fabricate(:post)
      whisper = Fabricate(:post, raw: 'this is a whisper post',
                                 user: Fabricate(:admin),
                                 topic: op.topic,
                                 reply_to_post_number: op.post_number,
                                 post_type: Post.types[:whisper])


      expect(PostAlerter.new.first_unread_post(op.user, op.topic)).to be_blank
    end
  end

  context 'likes' do
    it 'does not double notify users on likes' do
      ActiveRecord::Base.observers.enable :all

      post = Fabricate(:post, raw: 'I love waffles')
      PostAction.act(evil_trout, post, PostActionType.types[:like])

      admin = Fabricate(:admin)
      post.revise(admin, {raw: 'I made a revision'})

      PostAction.act(admin, post, PostActionType.types[:like])

      # one like and one edit notification
      expect(Notification.count(post_number: 1, topic_id: post.topic_id)).to eq(2)
    end
  end

  context 'quotes' do

    it 'does not notify for muted users' do
      post = Fabricate(:post, raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      MutedUser.create!(user_id: evil_trout.id, muted_user_id: post.user_id)

      expect {
        PostAlerter.post_created(post)
      }.to change(evil_trout.notifications, :count).by(0)
    end

    it 'notifies a user by username' do
      expect {
        create_post_with_alerts(raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      }.to change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      p1 = create_post_with_alerts(raw: '[quote="Evil Trout, post:1"]whatup[/quote]')
      expect {
        p1.revise(p1.user, { raw: '[quote="Evil Trout, post:1"]whatup now?[/quote]' })
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the poster" do
      topic = create_post_with_alerts.topic
      expect {
        Fabricate(:post, topic: topic, user: topic.user, raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]')
      }.not_to change(topic.user.notifications, :count)
    end
  end

  context 'linked' do
    it "will notify correctly on linking" do
      post1 = create_post
      user = post1.user
      create_post(raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      expect(user.notifications.count).to eq(1)

      create_post(user: user, raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      user.reload
      expect(user.notifications.count).to eq(1)

      # don't notify on reflection
      post1.reload
      expect(PostAlerter.new.extract_linked_users(post1).length).to eq(0)

    end
  end

  context '@mentions' do

    let(:user) { Fabricate(:user) }
    let(:mention_post) { create_post_with_alerts(user: user, raw: 'Hello @eviltrout')}
    let(:topic) { mention_post.topic }

    it 'notifies a user' do
      expect {
        mention_post
      }.to change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      expect {
        mention_post.revise(mention_post.user, { raw: "New raw content that still mentions @eviltrout" })
      }.not_to change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      expect {
        create_post_with_alerts(user: user, raw: 'second post', topic: topic)
      }.not_to change(user.notifications, :count)
    end

  end
end
