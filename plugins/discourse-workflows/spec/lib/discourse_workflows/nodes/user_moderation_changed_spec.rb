# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserModerationChanged::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:post) { Fabricate(:post, user: user) }

  it "dispatches moderation changes with safe actor data and filters selected changes" do
    freeze_time
    expiry = 1.day.from_now
    graph =
      build_workflow_graph do |builder|
        builder.node "moderation", described_class.identifier
        builder.node "suspended",
                     described_class.identifier,
                     configuration: {
                       changes: ["suspended"],
                     }
      end
    Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)

    UserSuspender.new(
      user,
      by_user: admin,
      reason: "Spam",
      message: "Bye",
      post_id: post.id,
      suspended_till: expiry,
    ).suspend
    UserSuspender.unsuspend(user, by_user: admin)
    UserSilencer.silence(
      user,
      admin,
      reason: "Spam",
      message_body: "Hush",
      post_id: post.id,
      silenced_till: expiry,
      keep_posts: true,
    )
    UserSilencer.unsilence(user, admin)

    jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
    data = jobs.filter_map { |job| job["trigger_data"] if job["trigger_node_id"] == "moderation" }
    expect(data.pluck("change")).to eq(%w[suspended unsuspended silenced unsilenced])
    expect(data.pluck("reason")).to eq(["Spam", nil, "Spam", nil])
    expect(data.pluck("expires_at")).to eq([expiry.iso8601, nil, expiry.iso8601, nil])
    expect(data.pluck("post_id")).to eq([post.id, nil, post.id, nil])
    expect(data.pluck("message")).to eq(["Bye", nil, "Hush", nil])
    expect(
      jobs.filter_map do |job|
        job["trigger_data"]["change"] if job["trigger_node_id"] == "suspended"
      end,
    ).to eq(["suspended"])
    data.each do |output|
      expect(output["user"]).to include("id" => user.id, "username" => user.username)
      expect(output["actor"]).to include("id" => admin.id, "username" => admin.username)
      expect(output["actor"]).not_to have_key("email")
      expect(output).to match_node_output_schema(described_class)
    end
  end

  it "preserves an unknown actor and reason" do
    user.update!(silenced_till: 1.day.from_now)

    output = described_class.from_event(:user_silenced, user: user).output

    expect(output).to include(
      actor: nil,
      reason: nil,
      message: nil,
      post_id: nil,
      expires_at: user.silenced_till.iso8601,
    )
    expect(output).to match_node_output_schema(described_class)
  end

  it "rejects missing users, bots, and unsupported events" do
    expect(described_class.from_event(:user_suspended, {})).not_to be_valid
    expect(described_class.from_event(:user_suspended, user: Discourse.system_user)).not_to be_valid
    expect(described_class.from_event(:user_updated, user: user)).not_to be_valid
  end

  it "stays registered but hidden, with its change filter", :aggregate_failures do
    expect(described_class).not_to be_palette_visible
    expect(described_class.properties).to have_key(:changes)
    expect(described_class.event_names).to eq(described_class::CHANGES.keys)
  end

  describe "User suspended, User unsuspended, User silenced and User unsilenced" do
    fab!(:moderator)

    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
    after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    let(:triggers) do
      {
        DiscourseWorkflows::Nodes::UserSuspended::V1 => :user_suspended,
        DiscourseWorkflows::Nodes::UserUnsuspended::V1 => :user_unsuspended,
        DiscourseWorkflows::Nodes::UserSilenced::V1 => :user_silenced,
        DiscourseWorkflows::Nodes::UserUnsilenced::V1 => :user_unsilenced,
      }
    end

    it "are palette triggers for one event each, without a change filter", :aggregate_failures do
      triggers.each do |node_class, event_name|
        expect(node_class).to be_palette_visible
        expect(node_class.version).to eq("1.0")
        expect(node_class.i18n_scope).to eq("user_moderation_changed")
        expect(node_class.event_names).to eq([event_name])
        expect(node_class.properties).to be_empty
        expect(node_class).to be_provides_current_user
      end
    end

    it "only build from their own event and ignore a stray change filter", :aggregate_failures do
      triggers.each do |node_class, event_name|
        other_event = (triggers.values - [event_name]).first
        trigger = node_class.from_event(event_name, user:, by_user: moderator)

        expect(node_class.from_event(other_event, user:, by_user: moderator)).not_to be_valid
        expect(trigger).to be_valid
        expect(trigger.user_id).to eq(user.id)
        expect(trigger.matches?(trigger_context(changes: ["nothing"]))).to eq(true)
      end
    end

    it "run workflows once per change, with the penalty details only for penalties",
       :aggregate_failures do
      freeze_time
      triggers.each_key do |node_class|
        graph =
          build_workflow_graph do |builder|
            builder.node node_class.identifier, node_class.identifier
          end
        Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
      end

      UserSuspender.new(
        user,
        by_user: moderator,
        reason: "Spam",
        message: "Bye",
        post_id: post.id,
        suspended_till: 1.day.from_now,
      ).suspend
      UserSuspender.unsuspend(user, by_user: moderator)
      UserSilencer.silence(user, moderator, reason: "Spam", silenced_till: 1.day.from_now)
      UserSilencer.unsilence(user, moderator)

      jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
      expect(jobs.pluck("trigger_node_id")).to eq(triggers.keys.map(&:identifier))
      expect(jobs.pluck("user_id")).to all(eq(user.id))
      jobs
        .zip(triggers.keys)
        .each do |job, node_class|
          data = job["trigger_data"]
          expect(data).to match_node_output_schema(node_class)
          expect(data["actor"]).to include("id" => moderator.id)
          expect(data).not_to have_key("change")
        end
      expect(jobs.first["trigger_data"]).to include(
        "reason" => "Spam",
        "message" => "Bye",
        "post_id" => post.id,
        "expires_at" => 1.day.from_now.iso8601,
      )
      expect(jobs.map { |job| job["trigger_data"].keys }).to eq(
        [
          %w[user actor reason message post_id expires_at],
          %w[user actor],
          %w[user actor reason message post_id expires_at],
          %w[user actor],
        ],
      )
    end

    it "report the system user when a suspension or a silence ends on its own",
       :aggregate_failures do
      freeze_time(Time.zone.now.round)
      UserSuspender.new(
        user,
        by_user: moderator,
        reason: "Spam",
        suspended_till: 1.hour.from_now,
      ).suspend
      UserSilencer.silence(user, moderator, reason: "Spam", silenced_till: 1.hour.from_now)
      user.update_columns(suspended_till: 1.minute.ago, silenced_till: 1.minute.ago)

      events =
        DiscourseEvent.track_events do
          UserSuspender.expire(
            user,
            suspended_at: user.suspended_at,
            suspended_till: user.suspended_till,
          )
          Jobs::UnsilenceUsers.new.execute({})
        end

      outputs =
        events.filter_map do |event|
          node_class = triggers.key(event[:event_name])
          node_class&.from_event(event[:event_name], *event[:params])&.output
        end
      expect(outputs).to contain_exactly(
        include(actor: include(id: Discourse.system_user.id)),
        include(actor: include(id: Discourse.system_user.id)),
      )
    end
  end
end
