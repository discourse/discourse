# frozen_string_literal: true

RSpec.describe "Outgoing calendar event webhooks" do
  fab!(:user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
  fab!(:web_hook, :outgoing_calendar_event_web_hook)

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:job_args) do
    Jobs::EmitWebHookEvent
      .jobs
      .map { |job| job["args"].first }
      .find { |args| args["event_type"] == "calendar_event" }
  end
  let(:event_name) { job_args["event_name"] }
  let(:payload) { JSON.parse(job_args["payload"]) }

  describe "calendar_event_created" do
    it "fires when a post with event markup is created" do
      post = create_post_with_event(user)
      event = post.reload.event

      expect(job_args).to be_present
      expect(event_name).to eq("calendar_event_created")
      expect(job_args["category_id"]).to eq(post.topic.category_id)

      expect(payload["event"]["id"]).to eq(event.id)
      expect(payload["event"]["starts_at"]).to be_present
      expect(payload["post"]["id"]).to eq(post.id)
      expect(payload["post"]["url"]).to eq(post.url)
      expect(payload["topic"]["id"]).to eq(post.topic_id)
      expect(payload["topic"]["title"]).to eq(post.topic.title)
      expect(payload["topic"]["category_id"]).to eq(post.topic.category_id)
    end
  end

  describe "calendar_event_updated" do
    let(:event_post) { create_post_with_event(user) }

    it "fires when an existing event is edited" do
      event_post

      revisor = PostRevisor.new(event_post, event_post.topic)
      revisor.revise!(user, raw: "[event start=\"#{1.day.from_now.utc.iso8601}\"]\n[/event]")

      job = find_webhook_job(:calendar_event_updated)
      expect(job).to be_present
      expect(job["event_name"]).to eq("calendar_event_updated")
    end

    it "fires calendar_event_created when event markup is added to an existing post" do
      post = Fabricate(:post, user: user)
      revisor = PostRevisor.new(post, post.topic)
      revisor.revise!(user, raw: "[event start=\"#{1.day.from_now.utc.iso8601}\"]\n[/event]")

      job = find_webhook_job(:calendar_event_created)
      expect(job).to be_present
      expect(job["event_name"]).to eq("calendar_event_created")
    end
  end

  describe "calendar_event_destroyed" do
    let(:event_post) { create_post_with_event(user) }
    it "fires when event markup is removed from a post" do
      event_post

      revisor = PostRevisor.new(event_post, event_post.topic)
      revisor.revise!(user, raw: "No event here.")

      job = find_webhook_job(:calendar_event_destroyed)
      expect(job).to be_present
      expect(job["event_name"]).to eq("calendar_event_destroyed")
    end

    it "fires when a post with an event is destroyed" do
      event_post

      event = event_post.reload.event
      PostDestroyer.new(user, event_post).destroy

      job = find_webhook_job(:calendar_event_destroyed)
      expect(job).to be_present
      expect(job["event_name"]).to eq("calendar_event_destroyed")
      expect(payload["event"]["id"]).to eq(event.id)
    end

    it "fires when DELETE /discourse-post-event/events/:id is called" do
      event_post
      sign_in(user)

      event = event_post.reload.event
      delete "/discourse-post-event/events/#{event.id}.json"

      job = find_webhook_job(:calendar_event_destroyed)
      expect(job).to be_present
      expect(job["event_name"]).to eq("calendar_event_destroyed")
      expect(payload["event"]["id"]).to eq(event.id)
    end
  end

  describe "calendar_event_created on post recovery" do
    let(:event_post) { create_post_with_event(user) }

    it "fires when a destroyed post with an event is recovered" do
      event_post
      PostDestroyer.new(user, event_post).destroy

      expect { PostDestroyer.new(user, event_post).recover }.to change {
        Jobs::EmitWebHookEvent.jobs.count do |j|
          j["args"].first["event_name"] == "calendar_event_created"
        end
      }.by(1)
    end
  end

  describe "WebHookEventType.active" do
    it "excludes all 3 calendar event types when discourse_post_event_enabled is false" do
      SiteSetting.discourse_post_event_enabled = false

      active_calendar_event_types =
        WebHookEventType.active.where(group: WebHookEventType.groups[:calendar])
      expect(active_calendar_event_types.count).to eq(0)
    end
  end

  def find_webhook_job(event_name)
    Jobs::EmitWebHookEvent
      .jobs
      .map { |job| job["args"].first }
      .find do |args|
        args["event_type"] == "calendar_event" && args["event_name"] == event_name.to_s
      end
  end
end
