require 'spec_helper'

describe PostAlerter do

  let!(:evil_trout) { Fabricate(:evil_trout) }

  def create_post_with_alerts(args={})
    post = Fabricate(:post, args)
    PostAlerter.post_created(post)
  end

  context 'quotes' do

    it 'notifies a user by username' do
      lambda {
        create_post_with_alerts(raw: '[quote="EvilTrout, post:1"]whatup[/quote]')
      }.should change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      p1 = create_post_with_alerts(raw: '[quote="Evil Trout, post:1"]whatup[/quote]')
      lambda {
        p1.revise(p1.user, { raw: '[quote="Evil Trout, post:1"]whatup now?[/quote]' })
      }.should_not change(evil_trout.notifications, :count)
    end

    it "doesn't notify the poster" do
      topic = create_post_with_alerts.topic
      lambda {
        Fabricate(:post, topic: topic, user: topic.user, raw: '[quote="Bruce Wayne, post:1"]whatup[/quote]')
      }.should_not change(topic.user.notifications, :count).by(1)
    end
  end

  context 'linked' do
    it "will notify correctly on linking" do
      post1 = create_post
      user = post1.user
      create_post(raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      user.notifications.count.should == 1

      create_post(user: user, raw: "my magic topic\n##{Discourse.base_url}#{post1.url}")

      user.reload
      user.notifications.count.should == 1

      # don't notify on reflection
      post1.reload
      PostAlerter.new.extract_linked_users(post1).length.should == 0

    end
  end

  context '@mentions' do

    let(:user) { Fabricate(:user) }
    let(:mention_post) { create_post_with_alerts(user: user, raw: 'Hello @eviltrout')}
    let(:topic) { mention_post.topic }

    it 'notifies a user' do
      lambda {
        mention_post
      }.should change(evil_trout.notifications, :count).by(1)
    end

    it "won't notify the user a second time on revision" do
      mention_post
      lambda {
        mention_post.revise(mention_post.user, { raw: "New raw content that still mentions @eviltrout" })
      }.should_not change(evil_trout.notifications, :count)
    end

    it "doesn't notify the user who created the topic in regular mode" do
      topic.notify_regular!(user)
      mention_post
      lambda {
        create_post_with_alerts(user: user, raw: 'second post', topic: topic)
      }.should_not change(user.notifications, :count).by(1)
    end

  end
end
