require 'rails_helper'

describe WebHook do
  it { is_expected.to validate_presence_of :payload_url }
  it { is_expected.to validate_presence_of :content_type }
  it { is_expected.to validate_presence_of :last_delivery_status }
  it { is_expected.to validate_presence_of :web_hook_event_types }

  describe '#content_types' do
    subject { WebHook.content_types }

    it "'json' (application/json) should be at 1st position" do
      expect(subject['application/json']).to eq(1)
    end

    it "'url_encoded' (application/x-www-form-urlencoded) should be at 2st position" do
      expect(subject['application/x-www-form-urlencoded']).to eq(2)
    end
  end

  describe '#last_delivery_statuses' do
    subject { WebHook.last_delivery_statuses }

    it "inactive should be at 1st position" do
      expect(subject[:inactive]).to eq(1)
    end

    it "failed should be at 2st position" do
      expect(subject[:failed]).to eq(2)
    end

    it "successful should be at 3st position" do
      expect(subject[:successful]).to eq(3)
    end
  end

  context 'web hooks' do
    let!(:post_hook) { Fabricate(:web_hook) }
    let!(:topic_hook) { Fabricate(:topic_web_hook) }

    describe '#find_by_type' do
      it 'find relevant hooks' do
        expect(WebHook.find_by_type(:post)).to eq([post_hook])
        expect(WebHook.find_by_type(:topic)).to eq([topic_hook])
      end

      it 'excludes inactive hooks' do
        post_hook.update_attributes!(active: false)

        expect(WebHook.find_by_type(:post)).to eq([])
        expect(WebHook.find_by_type(:topic)).to eq([topic_hook])
      end
    end

    describe '#enqueue_hooks' do
      it 'enqueues hooks with id and name' do
        Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, event_type: 'post')

        WebHook.enqueue_hooks(:post)
      end

      it 'accepts additional parameters' do
        Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, post_id: 1, event_type: 'post')

        WebHook.enqueue_hooks(:post, post_id: 1)
      end
    end

    context 'includes wildcard hooks' do
      let!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

      describe '#find_by_type' do
        it 'can find wildcard hooks' do
          expect(WebHook.find_by_type(:wildcard)).to eq([wildcard_hook])
        end

        it 'can include wildcard hooks' do
          expect(WebHook.find_by_type(:post).sort_by(&:id)).to eq([post_hook, wildcard_hook])
          expect(WebHook.find_by_type(:topic).sort_by(&:id)).to eq([topic_hook, wildcard_hook])

        end
      end

      describe '#enqueue_hooks' do
        it 'enqueues hooks with ids' do
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, event_type: 'post')
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: wildcard_hook.id, event_type: 'post')

          WebHook.enqueue_hooks(:post)
        end

        it 'accepts additional parameters' do
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: post_hook.id, post_id: 1, event_type: 'post')
          Jobs.expects(:enqueue).with(:emit_web_hook_event, web_hook_id: wildcard_hook.id, post_id: 1, event_type: 'post')

          WebHook.enqueue_hooks(:post, post_id: 1)
        end
      end
    end
  end

  describe 'enqueues hooks' do
    let!(:post_hook) { Fabricate(:web_hook) }
    let!(:topic_hook) { Fabricate(:topic_web_hook) }
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post) { Fabricate(:post, topic: topic, user: user) }
    let(:post2) { Fabricate(:post, topic: topic, user: user) }

    it 'should enqueue the right hooks for topic events' do
      WebHook.expects(:enqueue_topic_hooks).once
      PostCreator.create(user, { raw: 'post', title: 'topic', skip_validations: true })

      WebHook.expects(:enqueue_topic_hooks).once
      PostDestroyer.new(user, post).destroy

      WebHook.expects(:enqueue_topic_hooks).once
      PostDestroyer.new(user, post).recover
    end

    it 'should enqueue the right hooks for post events' do
      WebHook.expects(:enqueue_post_hooks).once
      PostCreator.create(user, { raw: 'post', topic_id: topic.id, reply_to_post_number: 1, skip_validations: true })

      # post destroy or recover triggers a moderator post
      WebHook.expects(:enqueue_post_hooks).twice
      PostDestroyer.new(user, post2).destroy

      WebHook.expects(:enqueue_post_hooks).twice
      PostDestroyer.new(user, post2).recover
    end

    it 'should enqueue the right hooks for user events' do
      WebHook.expects(:enqueue_hooks).once
      user

      WebHook.expects(:enqueue_hooks).once
      admin

      WebHook.expects(:enqueue_hooks).once
      user.approve(admin)

      WebHook.expects(:enqueue_hooks).once
      UserUpdater.new(admin, user).update(username: 'testing123')
    end
  end
end
