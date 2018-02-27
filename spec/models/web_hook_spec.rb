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
    let!(:post_hook) { Fabricate(:web_hook, payload_url: " https://example.com ") }
    let!(:topic_hook) { Fabricate(:topic_web_hook) }

    it "removes whitspace from payload_url before saving" do
      expect(post_hook.payload_url).to eq("https://example.com")
    end

    describe '#find_by_type' do
      it "returns unique hooks" do
        post_hook.web_hook_event_types << WebHookEventType.find_by(name: 'topic')
        post_hook.update!(wildcard_web_hook: true)

        expect(WebHook.find_by_type(:post)).to eq([post_hook])
      end

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
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post) { Fabricate(:post, topic: topic, user: user) }

    before do
      SiteSetting.queue_jobs = true
    end

    it 'should enqueue the right hooks for topic events' do
      Fabricate(:topic_web_hook)

      post = PostCreator.create(user, raw: 'post', title: 'topic', skip_validations: true)
      topic_id = post.topic_id
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_created")
      expect(job_args["topic_id"]).to eq(topic_id)

      PostDestroyer.new(user, post).destroy
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_destroyed")
      expect(job_args["topic_id"]).to eq(topic_id)

      PostDestroyer.new(user, post).recover
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_recovered")
      expect(job_args["topic_id"]).to eq(topic_id)

      %w{archived closed visible}.each do |status|
        post.topic.update_status(status, true, topic.user)
        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

        expect(job_args["event_name"]).to eq("topic_#{status}_status_updated")
        expect(job_args["topic_id"]).to eq(topic_id)
      end
    end

    describe 'when topic has been deleted' do
      it 'should not enqueue a post/topic edited hooks' do
        topic.trash!
        post.reload

        PostRevisor.new(post, topic).revise!(
          post.user,
          {
            category_id: Category.last.id,
            raw: "#{post.raw} new"
          },
          {}
        )

        expect(Jobs::EmitWebHookEvent.jobs.count).to eq(0)
      end
    end

    it 'should enqueue the right hooks for post events' do
      Fabricate(:web_hook)

      user
      topic

      post = PostCreator.create(user,
        raw: 'post',
        topic_id: topic.id,
        reply_to_post_number: 1,
        skip_validations: true
      )

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      Sidekiq::Worker.clear_all

      expect(job_args["event_name"]).to eq("post_created")
      expect(job_args["post_id"]).to eq(post.id)

      # post destroy or recover triggers a moderator post
      expect { PostDestroyer.new(user, post).destroy }
        .to change { Jobs::EmitWebHookEvent.jobs.count }.by(2)

      job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first

      expect(job_args["event_name"]).to eq("post_edited")
      expect(job_args["post_id"]).to eq(post.id)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("post_destroyed")
      expect(job_args["post_id"]).to eq(post.id)

      PostDestroyer.new(user, post).recover
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("post_recovered")
      expect(job_args["post_id"]).to eq(post.id)
    end

    it 'should enqueue the right hooks for user events' do
      Fabricate(:user_web_hook, active: true)

      user
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      expect(job_args["user_id"]).to eq(user.id)

      admin
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      expect(job_args["user_id"]).to eq(admin.id)

      user.approve(admin)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_approved")
      expect(job_args["user_id"]).to eq(user.id)

      UserUpdater.new(admin, user).update(username: 'testing123')
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_updated")
      expect(job_args["user_id"]).to eq(user.id)

      user.logged_out
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_logged_out")
      expect(job_args["user_id"]).to eq(user.id)

      user.logged_in
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_logged_in")
      expect(job_args["user_id"]).to eq(user.id)
    end
  end
end
