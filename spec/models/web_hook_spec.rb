# frozen_string_literal: true

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
    fab!(:post_hook) { Fabricate(:web_hook, payload_url: " https://example.com ") }
    fab!(:topic_hook) { Fabricate(:topic_web_hook) }

    it "removes whitespace from payload_url before saving" do
      expect(post_hook.payload_url).to eq("https://example.com")
    end

    it "excludes disabled plugin web_hooks" do
      web_hook_event_types = WebHookEventType.active.find_by(name: 'solved')
      expect(web_hook_event_types).to eq(nil)
    end

    it "includes non-plugin web_hooks" do
      web_hook_event_types = WebHookEventType.active.where(name: 'topic')
      expect(web_hook_event_types.count).to eq(1)
    end

    it "includes enabled plugin web_hooks" do
      SiteSetting.stubs(:solved_enabled).returns(true)
      web_hook_event_types = WebHookEventType.active.where(name: 'solved')
      expect(web_hook_event_types.count).to eq(1)
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
        fab!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

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
        WebHook.enqueue_hooks(:post, :post_created, payload: payload)

        job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first

        expect(job_args["web_hook_id"]).to eq(post_hook.id)
        expect(job_args["event_type"]).to eq('post')
        expect(job_args["payload"]).to eq(payload)
      end

      context 'includes wildcard hooks' do
        fab!(:wildcard_hook) { Fabricate(:wildcard_web_hook) }

        describe '#enqueue_hooks' do
          it 'enqueues hooks with ids' do
            WebHook.enqueue_hooks(:post, :post_created)

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
      it 'should not generate payload and enqueue anything for topic events' do
        topic_web_hook.destroy!
        post = PostCreator.create(user, raw: 'post', title: 'topic', skip_validations: true)
        expect(Jobs::EmitWebHookEvent.jobs.length).to eq(0)

        WebHook.expects(:generate_payload).times(0)
        PostDestroyer.new(admin, post).destroy
        expect(Jobs::EmitWebHookEvent.jobs.length).to eq(0)
      end

      it 'should not enqueue anything for tag events' do
        tag = Fabricate(:tag)
        tag.destroy!
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

      category = Fabricate(:category)

      expect do
        PostRevisor.new(post, post.topic).revise!(
          post.user,
          { category_id: category.id },
          { skip_validations: true },
        )
      end.to change { Jobs::EmitWebHookEvent.jobs.length }.by(1)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("topic_edited")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(topic_id)
      expect(payload["category_id"]).to eq(category.id)
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

    it 'should enqueue the destroyed hooks with tag filter for post events' do
      tag = Fabricate(:tag)
      Fabricate(:web_hook, tags: [tag])

      post = PostCreator.create!(user,
        raw: 'post',
        topic_id: topic.id,
        reply_to_post_number: 1,
        skip_validations: true
      )

      topic.tags = [tag]
      topic.save!

      Jobs::EmitWebHookEvent.jobs.clear
      PostDestroyer.new(user, post).destroy

      job = Jobs::EmitWebHookEvent.new
      job.expects(:send_webhook!).times(2)

      args = Jobs::EmitWebHookEvent.jobs[1]["args"].first
      job.execute(args.with_indifferent_access)

      args = Jobs::EmitWebHookEvent.jobs[2]["args"].first
      job.execute(args.with_indifferent_access)
    end

    it 'should enqueue the right hooks for user events' do
      SiteSetting.must_approve_users = true

      Fabricate(:user_web_hook, active: true)

      user
      Jobs::CreateUserReviewable.new.execute(user_id: user.id)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      email_token = Fabricate(:email_token, user: user)
      EmailToken.confirm(email_token.token)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_confirmed_email")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)

      admin
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(admin.id)

      ReviewableUser.find_by(target: user).perform(admin, :approve_user)
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

      email = user.email
      user.reload
      UserDestroyer.new(Discourse.system_user).destroy(user)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("user_destroyed")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(user.id)
      expect(payload["email"]).to eq(email)

      # Reflects runtime change to user field
      user_field = Fabricate(:user_field, show_on_profile: true)
      user.logged_in
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["event_name"]).to eq("user_logged_in")
      payload = JSON.parse(job_args["payload"])
      expect(payload["user_fields"].size).to eq(1)
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

    it 'should enqueue the right hooks for notifications' do
      Fabricate(:notification_web_hook)
      notification = Fabricate(:notification)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("notification_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(notification.id)
    end

    it 'should enqueue the right hooks for reviewables' do
      Fabricate(:reviewable_web_hook)
      reviewable = Fabricate(:reviewable)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("reviewable_created")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(reviewable.id)

      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:off_topic],
        reason: "test"
      )
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("reviewable_score_updated")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(reviewable.id)

      reviewable.perform(Discourse.system_user, :delete_user)
      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first

      expect(job_args["event_name"]).to eq("reviewable_transitioned_to")
      payload = JSON.parse(job_args["payload"])
      expect(payload["id"]).to eq(reviewable.id)
    end

    it 'should enqueue the right hooks for badge grants' do
      Fabricate(:user_badge_web_hook)
      badge = Fabricate(:badge)
      badge.multiple_grant = true
      badge.show_posts = true
      badge.save

      now = Time.now
      freeze_time now

      BadgeGranter.grant(badge, user, granted_by: admin, post_id: post.id)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["event_name"]).to eq("user_badge_granted")
      payload = JSON.parse(job_args["payload"])
      expect(payload["badge_id"]).to eq(badge.id)
      expect(payload["user_id"]).to eq(user.id)
      expect(payload["granted_by_id"]).to eq(admin.id)
      # be_within required because rounding occurs
      expect(Time.zone.parse(payload["granted_at"]).to_f).to be_within(0.001).of(now.to_f)
      expect(payload["post_id"]).to eq(post.id)

      # Future work: revoke badge hook
    end

    it 'should enqueue the right hooks for group user addition' do
      Fabricate(:group_user_web_hook)
      group = Fabricate(:group)

      now = Time.now
      freeze_time now

      group.add(user)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["event_name"]).to eq("user_added_to_group")
      payload = JSON.parse(job_args["payload"])
      expect(payload["group_id"]).to eq(group.id)
      expect(payload["user_id"]).to eq(user.id)
      expect(payload["notification_level"]).to eq(group.default_notification_level)
      expect(Time.zone.parse(payload["created_at"]).to_f).to be_within(0.001).of(now.to_f)
    end

    it 'should enqueue the right hooks for group user deletion' do
      Fabricate(:group_user_web_hook)
      group = Fabricate(:group)
      group_user = Fabricate(:group_user, group: group, user: user)

      now = Time.now
      freeze_time now

      group.remove(user)

      job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
      expect(job_args["event_name"]).to eq("user_removed_from_group")
      payload = JSON.parse(job_args["payload"])
      expect(payload["group_id"]).to eq(group.id)
      expect(payload["user_id"]).to eq(user.id)
    end

    context 'like created hooks' do
      fab!(:like_web_hook) { Fabricate(:like_web_hook) }
      fab!(:another_user) { Fabricate(:user) }

      it 'should pass the group id to the emit webhook job' do
        group = Fabricate(:group)
        group_user = Fabricate(:group_user, group: group, user: user)
        post = Fabricate(:post, user: another_user)
        like = Fabricate(:post_action, post: post, user: user, post_action_type_id: PostActionType.types[:like])
        now = Time.now
        freeze_time now

        DiscourseEvent.trigger(:like_created, like)

        assert_hook_was_queued_with(post, user, group_ids: [group.id])
      end

      it 'should pass the category id to the emit webhook job' do
        category = Fabricate(:category)
        topic.update!(category: category)
        like = Fabricate(:post_action, post: post, user: another_user, post_action_type_id: PostActionType.types[:like])

        DiscourseEvent.trigger(:like_created, like)

        assert_hook_was_queued_with(post, another_user, category_id: category.id)
      end

      it 'should pass the tag id to the emit webhook job' do
        tag = Fabricate(:tag)
        topic.update!(tags: [tag])
        like = Fabricate(:post_action, post: post, user: another_user, post_action_type_id: PostActionType.types[:like])

        DiscourseEvent.trigger(:like_created, like)

        assert_hook_was_queued_with(post, another_user, tag_ids: [tag.id])
      end

      def assert_hook_was_queued_with(post, user, group_ids: nil, category_id: nil, tag_ids: nil)
        job_args = Jobs::EmitWebHookEvent.jobs.last["args"].first
        expect(job_args["event_name"]).to eq("post_liked")
        payload = JSON.parse(job_args["payload"])
        expect(payload["post"]["id"]).to eq(post.id)
        expect(payload["user"]["id"]).to eq(user.id)

        expect(job_args["category_id"]).to eq(category_id) if category_id
        expect(job_args["group_ids"]).to contain_exactly(*group_ids) if group_ids
        expect(job_args["tag_ids"]).to contain_exactly(*tag_ids) if tag_ids
      end
    end
  end
end
