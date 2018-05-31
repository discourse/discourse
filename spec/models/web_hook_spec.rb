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

    describe '#active_web_hooks' do
      it "returns unique hooks" do
        post_hook.web_hook_event_types << WebHookEventType.find_by(name: 'topic')
        post_hook.update!(wildcard_web_hook: true)

        expect(WebHook.active_web_hooks(:post)).to eq([post_hook])
      end

      it 'find relevant hooks' do
        expect(WebHook.active_web_hooks(:post)).to eq([post_hook])
        expect(WebHook.active_web_hooks(:topic)).to eq([topic_hook])
      end

      it 'excludes inactive hooks' do
        post_hook.update!(active: false)

        expect(WebHook.active_web_hooks(:post)).to eq([])
        expect(WebHook.active_web_hooks(:topic)).to eq([topic_hook])
      end

      describe 'wildcard web hooks' do
        let!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

        it 'should include wildcard hooks' do
          expect(WebHook.active_web_hooks(:wildcard)).to eq([wildcard_hook])

          expect(WebHook.active_web_hooks(:post)).to contain_exactly(
            post_hook, wildcard_hook
          )

          expect(WebHook.active_web_hooks(:topic)).to contain_exactly(
            topic_hook, wildcard_hook
          )
        end
      end
    end

    describe '#enqueue_hooks' do
      it 'accepts additional parameters' do
        payload = { test: 'some payload' }.to_json
        WebHook.enqueue_hooks(:post, payload: payload)

        job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first

        expect(job_args["web_hook_id"]).to eq(post_hook.id)
        expect(job_args["event_type"]).to eq('post')
        expect(job_args["payload"]).to eq(payload)
      end

      context 'includes wildcard hooks' do
        let!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

        describe '#enqueue_hooks' do
          it 'enqueues hooks with ids' do
            WebHook.enqueue_hooks(:post)

            job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first

            expect(job_args["web_hook_id"]).to eq(post_hook.id)
            expect(job_args["event_type"]).to eq('post')

            job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

            expect(job_args["web_hook_id"]).to eq(wildcard_hook.id)
            expect(job_args["event_type"]).to eq('post')
          end
        end
      end
    end
  end

  describe 'enqueues hooks' do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:post) { Fabricate(:post, topic: topic, user: user) }
    let(:topic_web_hook) { Fabricate(:topic_web_hook) }

    before do
      topic_web_hook
    end

    describe 'when there are no active hooks' do
      it 'should not enqueue anything' do
        topic_web_hook.destroy!
        post = PostCreator.create(user, raw: 'post', title: 'topic', skip_validations: true)
        expect(Jobs::EmitWebHookEvent.jobs.length).to eq(0)
      end
    end

    it 'should enqueue the right hooks for topic events' do
      post = PostCreator.create(user, raw: 'post', title: 'topic', skip_validations: true)
      topic_id = post.topic.id
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(topic_id)

      PostDestroyer.new(user, post).destroy
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(topic_id)

      PostDestroyer.new(user, post).recover
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_recovered")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(topic_id)

      %w{archived closed visible}.each do |status|
        post.topic.update_status(status, true, topic.user)
        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

        expect(job_args["event_name"]).to eq("topic_#{status}_status_updated")
        payload = JSON.parse(job_args["payload"])
        expect(payload["id"]).to eq(topic_id)
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

      post = PostCreator.create!(user,
        raw: 'post',
        topic_id: topic.id,
        reply_to_post_number: 1,
        skip_validations: true
      )

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("post_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.id)

      Jobs::EmitWebHookEvent.jobs.clear

      # post destroy or recover triggers a moderator post
      expect { PostDestroyer.new(user, post).destroy }
        .to change { Jobs::EmitWebHookEvent.jobs.count }.by(3)

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("post_edited")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.id)

      job_args = Jobs::EmitWebHookEvent.jobs[1]["args"].first

      expect(job_args["event_name"]).to eq("post_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.id)

      job_args = Jobs::EmitWebHookEvent.jobs[2]["args"].first

      expect(job_args["event_name"]).to eq("topic_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.topic.id)

      Jobs::EmitWebHookEvent.jobs.clear

      expect { PostDestroyer.new(user, post).recover }
        .to change { Jobs::EmitWebHookEvent.jobs.count }.by(3)

      job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

      expect(job_args["event_name"]).to eq("post_edited")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.id)

      job_args = Jobs::EmitWebHookEvent.jobs[1]["args"].first

      expect(job_args["event_name"]).to eq("post_recovered")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.id)

      job_args = Jobs::EmitWebHookEvent.jobs[2]["args"].first

      expect(job_args["event_name"]).to eq("topic_recovered")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post.topic.id)
    end

    it 'should enqueue the right hooks for user events' do
      Fabricate(:user_web_hook, active: true)

      user
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      admin
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(admin.id)

      user.approve(admin)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_approved")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      UserUpdater.new(admin, user).update(username: 'testing123')
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_updated")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      user.logged_out
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_logged_out")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      user.logged_in
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_logged_in")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)
    end

    it 'should enqueue the right hooks for category events' do
      Fabricate(:category_web_hook)
      category = Fabricate(:category)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("category_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(category.id)

      category.update!(slug: 'testing')

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("category_updated")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(category.id)
      expect(payload["slug"]).to eq('testing')

      category.destroy!

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("category_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(category.id)
    end

    it 'should enqueue the right hooks for group events' do
      Fabricate(:group_web_hook)
      group = Fabricate(:group)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("group_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(group.id)

      group.update!(full_name: 'testing')
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("group_updated")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(group.id)
      expect(payload["full_name"]).to eq('testing')

      group.destroy!
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("group_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["full_name"]).to eq('testing')
    end

    it 'should enqueue the right hooks for tag events' do
      Fabricate(:tag_web_hook)
      tag = Fabricate(:tag)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("tag_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(tag.id)

      tag.update!(name: 'testing')
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("tag_updated")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(tag.id)
      expect(payload["name"]).to eq('testing')

      tag.destroy!

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("tag_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(tag.id)
    end

    it 'should enqueue the right hooks for flag events' do
      post = Fabricate(:post)
      admin = Fabricate(:admin)
      moderator = Fabricate(:moderator)
      Fabricate(:flag_web_hook)

      post_action = PostAction.act(admin, post, PostActionType.types[:spam])
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("flag_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post_action.id)

      PostAction.agree_flags!(post, moderator)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("flag_agreed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post_action.id)

      PostAction.clear_flags!(post, moderator)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("flag_disagreed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post_action.id)

      post = Fabricate(:post)
      post_action = PostAction.act(admin, post, PostActionType.types[:spam])
      PostAction.defer_flags!(post, moderator)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("flag_deferred")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(post_action.id)
    end
  end
end
