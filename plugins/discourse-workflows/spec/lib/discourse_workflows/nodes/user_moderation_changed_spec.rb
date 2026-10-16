# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserModerationChanged::V1 do
  fab!(:user)
  fab!(:admin)

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

    UserSuspender.new(user, by_user: admin, reason: "Spam", suspended_till: expiry).suspend
    UserSuspender.unsuspend(user, by_user: admin)
    UserSilencer.silence(user, admin, reason: "Spam", silenced_till: expiry, keep_posts: true)
    UserSilencer.unsilence(user, admin)

    jobs = Jobs::DiscourseWorkflows::ExecuteWorkflow.jobs.map { |job| job["args"].first }
    data = jobs.filter_map { |job| job["trigger_data"] if job["trigger_node_id"] == "moderation" }
    expect(data.pluck("change")).to eq(%w[suspended unsuspended silenced unsilenced])
    expect(data.pluck("reason")).to eq(["Spam", nil, "Spam", nil])
    expect(data.pluck("expires_at")).to eq([expiry.iso8601, nil, expiry.iso8601, nil])
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

    expect(output).to include(actor: nil, reason: nil, expires_at: user.silenced_till.iso8601)
    expect(output).to match_node_output_schema(described_class)
  end

  it "rejects missing users, bots, and unsupported events" do
    expect(described_class.from_event(:user_suspended, {})).not_to be_valid
    expect(described_class.from_event(:user_suspended, user: Discourse.system_user)).not_to be_valid
    expect(described_class.from_event(:user_updated, user: user)).not_to be_valid
  end
end
