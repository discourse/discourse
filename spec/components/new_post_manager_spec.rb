require 'rails_helper'
require 'new_post_manager'

describe NewPostManager do

  let(:topic) { Fabricate(:topic) }

  context "default action" do
    it "creates the post by default" do
      manager = NewPostManager.new(topic.user, raw: 'this is a new post', topic_id: topic.id)
      result = manager.perform

      expect(result.action).to eq(:create_post)
      expect(result).to be_success
      expect(result.post).to be_present
      expect(result.post).to be_a(Post)
    end
  end

  context "default action" do
    let(:other_user) { Fabricate(:user) }

    shared_examples "actions" do
      it "doesn't enqueue private messages" do
        SiteSetting.approve_unless_trust_level = 4

        manager = NewPostManager.new(topic.user,
                                     raw: 'this is a new post',
                                     title: 'this is a new title',
                                     archetype: Archetype.private_message,
                                     target_usernames: other_user.username)

        result = manager.perform

        expect(result.action).to eq(:create_post)
        expect(result).to be_success
        expect(result.post).to be_present
        expect(result.post.topic.private_message?).to eq(true)
        expect(result.post).to be_a(Post)

        # It doesn't enqueue replies to the private message either
        manager = NewPostManager.new(topic.user,
                                     raw: 'this is a new reply',
                                     topic_id: result.post.topic_id)

        result = manager.perform

        expect(result.action).to eq(:create_post)
        expect(result).to be_success
        expect(result.post).to be_present
        expect(result.post.topic.private_message?).to eq(true)
        expect(result.post).to be_a(Post)
      end
    end

    context "without queued_preview posting" do
      include_examples "actions"
    end

    context "with queued_preview posting" do
      before(:each) do
        SiteSetting.stubs(:queued_preview_mode).returns(true)
      end

      include_examples "actions"
    end

  end

  context "default handler" do
    let(:manager) { NewPostManager.new(topic.user, raw: 'this is new post content', topic_id: topic.id) }

    shared_examples "enqueue_positive" do
      it "will return an enqueue result" do
          result = NewPostManager.default_handler(manager)
          expect(NewPostManager.queue_enabled?).to be true
          expect(result.action).to eq(:enqueued)
      end
    end

    shared_examples "enqueue_negative" do
      it "won't return an enqueue result" do
          result = NewPostManager.default_handler(manager)
          expect(NewPostManager.queue_enabled?).to be false
          expect(result).to be_nil
      end
    end

    context "without queued_preview posting" do
      context 'with a high approval post count and TL0' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 0
        end

        context 'with a high approval post count' do
          before do
            SiteSetting.approve_post_count = 100
          end
          include_examples "enqueue_positive"
        end

        context 'with a high trust level setting' do
          before do
            SiteSetting.approve_unless_trust_level = 4
          end
          include_examples "enqueue_positive"
        end
      end

      context 'with a high approval post count and TL1' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 1
        end
        include_examples "enqueue_positive"
      end

      context 'with a high approval post count, but TL2' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 2
        end
        it "will return an enqueue result" do
          result = NewPostManager.default_handler(manager)
          expect(result).to be_nil
        end
      end

      context 'with a high trust level setting' do
        before do
          SiteSetting.approve_unless_trust_level = 4
        end

        context 'with the settings zeroed out' do
          before do
            SiteSetting.approve_post_count = 0
            SiteSetting.approve_unless_trust_level = 0
          end
          include_examples "enqueue_negative"
        end

        context 'with a high approval post count' do
          before do
            SiteSetting.approve_post_count = 100
          end
          include_examples "enqueue_positive"
        end

        context 'with a high trust level setting' do
          before do
            SiteSetting.approve_unless_trust_level = 4
          end
          include_examples "enqueue_positive"
        end
      end
    end

    context "with queued_preview posting" do
      before(:each) do
        SiteSetting.stubs(:queued_preview_mode).returns(true)
      end

      context 'with a high approval post count and TL0' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 0
        end

        context 'with a high approval post count' do
          before do
            SiteSetting.approve_post_count = 100
          end
          include_examples "enqueue_positive"
        end

        context 'with a high trust level setting' do
          before do
            SiteSetting.approve_unless_trust_level = 4
          end
          include_examples "enqueue_positive"
        end
      end

      context 'with a high approval post count and TL1' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 1
        end
        include_examples "enqueue_positive"
      end

      context 'with a high approval post count, but TL2' do
        before do
          SiteSetting.approve_post_count = 100
          topic.user.trust_level = 2
        end
        include_examples "enqueue_positive"
      end

      context 'with a high trust level setting' do
        before do
          SiteSetting.approve_unless_trust_level = 4
        end

        context 'with the settings zeroed out' do
          before do
            SiteSetting.approve_post_count = 0
            SiteSetting.approve_unless_trust_level = 0
          end
          include_examples "enqueue_positive"
        end

        context 'with a high approval post count' do
          before do
            SiteSetting.approve_post_count = 100
          end
          include_examples "enqueue_positive"
        end

        context 'with a high trust level setting' do
          before do
            SiteSetting.approve_unless_trust_level = 4
          end
          include_examples "enqueue_positive"
        end
      end
    end
  end

  context "extensibility priority" do

    after do
      NewPostManager.clear_handlers!
    end

    let(:default_handler) { NewPostManager.method(:default_handler) }

    it "adds in order by default" do
      handler = ->{ nil }

      NewPostManager.add_handler(&handler)
      expect(NewPostManager.handlers).to eq([default_handler, handler])
    end

    it "can be added in high priority" do
      a = ->{ nil }
      b = ->{ nil }
      c = ->{ nil }

      NewPostManager.add_handler(100, &a)
      NewPostManager.add_handler(50, &b)
      NewPostManager.add_handler(101, &c)
      expect(NewPostManager.handlers).to eq([c, a, b, default_handler])
    end

  end

  context "extensibility" do

    before do
      @counter = 0

      @counter_handler = lambda do |manager|
        result = nil
        if manager.args[:raw] == 'this post increases counter'
          @counter += 1
          result = NewPostResult.new(:counter, true)
        end

        result
      end

      @queue_handler = -> (manager) { manager.args[:raw] =~ /queue me/ ? manager.enqueue('default') : nil }
    end

    after do
      NewPostManager.clear_handlers!
    end

    shared_examples "common" do
      it "has a queue enabled" do
        expect(NewPostManager.queue_enabled?).to eq(true)
      end

      it "calls custom handlers" do
        manager = NewPostManager.new(topic.user, raw: 'this post increases counter', topic_id: topic.id)

        result = manager.perform
        expect(result.action).to eq(:counter)
        expect(result).to be_success
        expect(result.post).to be_blank
        expect(@counter).to be(1)
        expect(QueuedPost.new_count).to be(0)
      end
    end

    context "without queued_preview approval" do

      before do
        NewPostManager.add_handler(&@counter_handler)
        NewPostManager.add_handler(&@queue_handler)
      end

      include_examples "common"

      it "calls custom enqueuing handlers" do
        manager = NewPostManager.new(topic.user, raw: 'to the handler I say enqueue me!', title: 'this is the title of the queued post')

        result = manager.perform

        enqueued = result.queued_post

        expect(enqueued).to be_present
        expect(enqueued.post_options['title']).to eq('this is the title of the queued post')
        expect(result.action).to eq(:enqueued)
        expect(result).to be_success
        expect(result.pending_count).to eq(1)
        expect(result.post).to be_blank
        expect(QueuedPost.new_count).to eq(1)
        expect(@counter).to be(0)
      end

      it "if nothing returns a result it creates a post" do
        manager = NewPostManager.new(topic.user, raw: 'this is a new post', topic_id: topic.id)

        result = manager.perform

        expect(result.action).to eq(:create_post)
        expect(result).to be_success
        expect(result.post).to be_present
        expect(@counter).to be(0)
      end
    end

    context "with queued_preview approval" do
      before(:each) do
        NewPostManager.add_handler(1, &@counter_handler)
        NewPostManager.add_handler(1, &@queue_handler)

        SiteSetting.stubs(:queued_preview_mode).returns(true)
      end

      include_examples "common"

      it "calls custom enqueuing handlers and create a queued_preview post" do
        manager = NewPostManager.new(topic.user, raw: 'to the handler I say enqueue me!', title: 'this is the title of the queued post')

        result = manager.perform

        expect(result).to be_success
        expect(result.queued_post).to be_nil
        expect(result.post).to be_present
        expect(result.post.queued_preview_post_map).to be_present

        enqueued = result.post.queued_preview_post_map.queued_post
        expect(enqueued).to be_present
        expect(enqueued.post_options['title']).to eq('this is the title of the queued post')
        expect(QueuedPost.new_count).to eq(1)

        expect(@counter).to be(0)
      end

      it "if nothing returns a result it creates a queued_preview post" do
        manager = NewPostManager.new(topic.user, raw: 'this is a new post', topic_id: topic.id)

        result = manager.perform

        expect(result).to be_success
        expect(result.queued_post).to be_nil
        expect(result.post).to be_present
        expect(result.post.queued_preview_post_map).to be_present

        enqueued = result.post.queued_preview_post_map.queued_post
        expect(enqueued).to be_present
        expect(enqueued.raw).to eq(result.post.raw)
        expect(QueuedPost.new_count).to eq(1)

        expect(@counter).to be(0)
      end
    end
  end


  context "user needs approval?" do

    let :user do
      user = Fabricate.build(:user, trust_level: 0)
      user_stat = UserStat.new(post_count: 0)
      user.user_stat = user_stat
      user
    end

    it "handles user_needs_approval? correctly without queued_preview approval" do
      u = user
      default = NewPostManager.new(u,{})
      expect(NewPostManager.user_needs_approval?(default)).to eq(false)

      with_check = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check)).to eq(true)

      u.user_stat.post_count = 1
      with_check_and_post = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check_and_post)).to eq(false)

      u.user_stat.post_count = 0
      u.trust_level = 1
      with_check_tl1 = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check_tl1)).to eq(false)
    end

    it "handles user_needs_approval? correctly with queued_preview approval" do
      SiteSetting.queued_preview_mode = true

      u = user
      default = NewPostManager.new(u,{})
      expect(NewPostManager.user_needs_approval?(default)).to eq(true)

      with_check = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check)).to eq(true)

      u.user_stat.post_count = 1
      with_check_and_post = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check_and_post)).to eq(true)

      u.user_stat.post_count = 0
      u.trust_level = 1
      with_check_tl1 = NewPostManager.new(u,{first_post_checks: true})
      expect(NewPostManager.user_needs_approval?(with_check_tl1)).to eq(true)
    end
  end

end
