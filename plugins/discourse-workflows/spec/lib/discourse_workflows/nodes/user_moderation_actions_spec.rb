# frozen_string_literal: true

RSpec.shared_context "with a user to moderate" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:post) { Fabricate(:post, user:) }

  before { DiscourseWorkflows::WorkflowDependency.clear_cache! }
  after { DiscourseWorkflows::WorkflowDependency.clear_cache! }

  def run_node(username: user.username, actor_username: moderator.username, **configuration)
    execute_node(
      configuration: {
        "username" => username,
        "actor_username" => actor_username,
        **configuration.stringify_keys,
      },
    )
  end

  def moderation_error(key, **args)
    node_error_message(key, scope: "user_moderation_action", item_index: 0, **args)
  end

  def staff_logs(action)
    UserHistory.where(action: UserHistory.actions[action], target_user_id: user.id)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::SuspendUser::V1 do
  include_context "with a user to moderate"

  before { freeze_time Time.utc(2026, 10, 1, 12) }

  def suspend(**configuration)
    run_node(reason: "Spamming", **configuration)
  end

  it "suspends the user for a duration as the actor", :aggregate_failures do
    result = nil
    events =
      DiscourseEvent.track_events(:user_suspended) do
        result = suspend(duration: 2, duration_unit: "weeks", message: "Take a break")
      end

    expect(result).to include(
      "user" => include("id" => user.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
      "expires_at" => 2.weeks.from_now.iso8601,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(user.reload).to be_suspended
    expect(staff_logs(:suspend_user).sole).to have_attributes(
      acting_user_id: moderator.id,
      details: include("Spamming", "Take a break"),
    )
    expect(events.sole[:params].sole).to include(user:, by_user: moderator, reason: "Spamming")
  end

  it "suspends until a time in the node's timezone" do
    suspend(schedule: "at_time", suspended_till: "2026-12-01 09:00", timezone: "Europe/Paris")

    expect(user.reload.suspended_till).to eq_time(Time.utc(2026, 12, 1, 8))
  end

  it "links the suspension to a deleted post", :aggregate_failures do
    post.trash!(admin)

    events = DiscourseEvent.track_events(:user_suspended) { suspend(post_id: post.id.to_s) }

    expect(staff_logs(:suspend_user).sole.post_id).to eq(post.id)
    expect(events.sole[:params].sole).to include(post_id: post.id)
  end

  it "reports nothing changed and keeps the suspension when the user is already suspended",
     :aggregate_failures do
    UserSuspender.new(user, suspended_till: 1.day.from_now, reason: "First", by_user: admin).suspend

    result = nil
    events = DiscourseEvent.track_events(:user_suspended) { result = suspend(duration: 30) }

    expect(result).to include("changed" => false, "expires_at" => 1.day.from_now.iso8601)
    expect(staff_logs(:suspend_user).count).to eq(1)
    expect(events).to be_empty
  end

  it "reports nothing changed for a suspended user whose penalty history was reset" do
    UserSuspender.new(user, suspended_till: 1.day.from_now, reason: "First", by_user: admin).suspend
    staff_logs(:suspend_user).delete_all

    expect(suspend).to include("changed" => false)
  end

  it "suspends again once a suspension has ended" do
    user.update!(suspended_at: 2.days.ago, suspended_till: 1.day.ago)

    expect(suspend).to include("changed" => true, "expires_at" => 7.days.from_now.iso8601)
  end

  it "refuses actors who aren't staff, even when the user is already suspended" do
    UserSuspender.new(user, suspended_till: 1.day.from_now, reason: "First", by_user: admin).suspend
    member = Fabricate(:user)

    expect { suspend(actor_username: member.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("suspend_not_allowed", username: member.username, target: user.username),
    )
  end

  it "refuses to suspend staff" do
    expect { suspend(username: admin.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("suspend_not_allowed", username: moderator.username, target: admin.username),
    )
  end

  it "fails for a missing user" do
    expect { suspend(username: "nobody") }.to raise_error(
      DiscourseWorkflows::NodeError,
      node_error_message("not_found", scope: "actor", item_index: 0, username: "nobody"),
    )
  end

  it "refuses a missing or too long reason", :aggregate_failures do
    expect { run_node(reason: "") }.to raise_error(DiscourseWorkflows::NodeError, /Reason/)
    expect { run_node(reason: "a" * 301) }.to raise_error(DiscourseWorkflows::NodeError, /Reason/)
    expect(user.reload).not_to be_suspended
  end

  it "refuses durations that aren't a positive number of units up to 1000 years",
     :aggregate_failures do
    [0, -1, "soon", 1001].each do |duration|
      expect { suspend(duration:, duration_unit: "years") }.to raise_error(
        DiscourseWorkflows::NodeError,
        moderation_error("invalid_duration", value: duration),
      )
    end
    expect { suspend(duration_unit: "fortnights") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("invalid_duration_unit", duration_unit: "fortnights"),
    )
    expect { suspend(schedule: "whenever") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("invalid_schedule", schedule: "whenever"),
    )
    expect(user.reload).not_to be_suspended
  end

  it "accepts 1000 years as a suspension that never ends" do
    expect(suspend(duration: 1000, duration_unit: "years")).to include(
      "expires_at" => 1000.years.from_now.iso8601,
    )
  end

  it "refuses an end time that is missing, unreadable or past", :aggregate_failures do
    expect { suspend(schedule: "at_time") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("time_required", field: "suspended_till"),
    )
    expect { suspend(schedule: "at_time", suspended_till: "soon") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("invalid_time", field: "suspended_till", value: "soon"),
    )
    expect { suspend(schedule: "at_time", suspended_till: "2026-09-30 12:00") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error(
        "time_in_past",
        field: "suspended_till",
        value: Time.utc(2026, 9, 30, 12).iso8601,
      ),
    )
    expect(user.reload).not_to be_suspended
  end

  it "refuses a post that never existed" do
    expect { suspend(post_id: "0") }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("post_not_found", post_id: "0"),
    )
  end

  it "turns a failed save into a node error" do
    user.errors.add(:base, "Broken")
    allow(UserSuspender).to receive(:new).and_raise(ActiveRecord::RecordInvalid.new(user))

    expect { suspend }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("invalid", username: user.username, errors: "Broken"),
    )
  end

  it "validates the timezone in the configuration" do
    errors = ActiveModel::Errors.new(DiscourseWorkflows::Workflow.new)

    described_class.validate_configuration({ "timezone" => "Mars/Olympus" }, errors)

    expect(errors.full_messages).to contain_exactly(
      I18n.t("discourse_workflows.errors.invalid_timezone", timezone: "Mars/Olympus"),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::SilenceUser::V1 do
  include_context "with a user to moderate"

  before { freeze_time Time.utc(2026, 10, 1, 12) }

  def silence(**configuration)
    run_node(reason: "Spamming", **configuration)
  end

  it "silences the user as the actor, keeping their posts visible", :aggregate_failures do
    result = nil
    events =
      DiscourseEvent.track_events(:user_silenced) do
        result = silence(duration: 3, duration_unit: "days", message: "Calm down")
      end

    expect(result).to include(
      "user" => include("id" => user.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
      "expires_at" => 3.days.from_now.iso8601,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(user.reload).to be_silenced
    expect(post.reload).not_to be_hidden
    expect(staff_logs(:silence_user).sole).to have_attributes(
      acting_user_id: moderator.id,
      details: include("Spamming", "Calm down"),
    )
    expect(events.sole[:params].sole).to include(user:, silenced_by: moderator)
  end

  it "silences until a time in the node's timezone" do
    silence(schedule: "at_time", silenced_till: "2026-12-01 09:00", timezone: "Europe/Paris")

    expect(user.reload.silenced_till).to eq_time(Time.utc(2026, 12, 1, 8))
  end

  it "links the silence to a deleted post" do
    post.trash!(admin)

    silence(post_id: post.id.to_s)

    expect(staff_logs(:silence_user).sole.post_id).to eq(post.id)
  end

  it "reports nothing changed and keeps the silence when the user is already silenced",
     :aggregate_failures do
    UserSilencer.silence(user, admin, silenced_till: 1.day.from_now, reason: "First")

    result = nil
    events = DiscourseEvent.track_events(:user_silenced) { result = silence(duration: 30) }

    expect(result).to include("changed" => false, "expires_at" => 1.day.from_now.iso8601)
    expect(staff_logs(:silence_user).count).to eq(1)
    expect(events).to be_empty
  end

  it "refuses actors who aren't staff, and staff targets", :aggregate_failures do
    member = Fabricate(:user)

    expect { silence(actor_username: member.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("silence_not_allowed", username: member.username, target: user.username),
    )
    expect { silence(username: admin.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("silence_not_allowed", username: moderator.username, target: admin.username),
    )
  end

  it "silences the account behind an anonymous user, reporting the anonymous user",
     :aggregate_failures do
    SiteSetting.allow_anonymous_mode = true
    shadow = Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: user) }

    result = nil
    events =
      DiscourseEvent.track_events(:user_silenced) { result = silence(username: shadow.username) }

    expect(result).to include("user" => include("id" => shadow.id), "changed" => true)
    expect(result["user"]).not_to include("id" => user.id)
    expect(user.reload).to be_silenced
    expect(events.sole[:params].sole).to include(user: shadow)
  end

  it "silences again a user whose silence ended but hasn't been lifted yet" do
    UserSilencer.silence(user, admin, silenced_till: 1.day.from_now, reason: "First")
    user.update_columns(silenced_till: 1.minute.ago)

    events = DiscourseEvent.track_events(:user_silenced) { silence }

    expect(events.sole[:params].sole).to include(user:, silenced_by: moderator)
  end

  it "validates the timezone in the configuration" do
    errors = ActiveModel::Errors.new(DiscourseWorkflows::Workflow.new)

    described_class.validate_configuration({ "timezone" => "Mars/Olympus" }, errors)

    expect(errors.full_messages).to contain_exactly(
      I18n.t("discourse_workflows.errors.invalid_timezone", timezone: "Mars/Olympus"),
    )
  end

  it "turns a silence that couldn't be saved into a node error" do
    allow_any_instance_of(UserSilencer).to receive(:silence).and_return(nil)

    expect { silence }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("failed", username: user.username),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnsuspendUser::V1 do
  include_context "with a user to moderate"

  it "unsuspends the user as the actor", :aggregate_failures do
    UserSuspender.new(user, suspended_till: 1.day.from_now, reason: "Spam", by_user: admin).suspend

    result = nil
    events = DiscourseEvent.track_events(:user_unsuspended) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(user.reload).not_to be_suspended
    expect(staff_logs(:unsuspend_user).sole.acting_user_id).to eq(moderator.id)
    expect(events.sole[:params].sole).to include(user:, by_user: moderator)
  end

  it "reports nothing changed when the user isn't suspended" do
    events =
      DiscourseEvent.track_events(:user_unsuspended) do
        expect(run_node).to include("changed" => false)
      end

    expect(events).to be_empty
  end

  it "keeps the dates of a suspension whose end was already reported", :aggregate_failures do
    freeze_time(Time.zone.now.round)
    suspended_at = 2.days.ago
    suspended_till = 1.day.ago
    user.update!(suspended_at:, suspended_till:)
    UserSuspender.expire(user, suspended_at: user.suspended_at, suspended_till: user.suspended_till)

    result = nil
    events = DiscourseEvent.track_events(:user_unsuspended) { result = run_node }

    expect(result).to include("changed" => false)
    expect(user.reload.suspended_till).to eq_time(suspended_till)
    expect(events).to be_empty
  end

  it "ends and reports a suspension that ended without being reported" do
    user.update!(suspended_at: 2.days.ago, suspended_till: 1.day.ago)

    events =
      DiscourseEvent.track_events(:user_unsuspended) do
        expect(run_node).to include("changed" => true)
      end

    expect(events.sole[:params].sole).to include(by_user: moderator)
  end

  it "lets only admins unsuspend staff, and refuses actors who aren't staff", :aggregate_failures do
    other_moderator =
      Fabricate(:moderator, suspended_at: 1.hour.ago, suspended_till: 1.day.from_now)
    member = Fabricate(:user)

    expect { run_node(username: other_moderator.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error(
        "unsuspend_not_allowed",
        username: moderator.username,
        target: other_moderator.username,
      ),
    )
    expect { run_node(actor_username: member.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("unsuspend_not_allowed", username: member.username, target: user.username),
    )
    expect(run_node(username: other_moderator.username, actor_username: admin.username)).to include(
      "changed" => true,
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnsilenceUser::V1 do
  include_context "with a user to moderate"

  it "unsilences the user as the actor", :aggregate_failures do
    UserSilencer.silence(user, admin, silenced_till: 1.day.from_now, reason: "Spam")

    result = nil
    events = DiscourseEvent.track_events(:user_unsilenced) { result = run_node }

    expect(result).to include(
      "user" => include("id" => user.id),
      "actor" => include("id" => moderator.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(user.reload).not_to be_silenced
    expect(staff_logs(:unsilence_user).sole.acting_user_id).to eq(moderator.id)
    expect(events.sole[:params].sole).to include(user:, by_user: moderator)
  end

  it "reports nothing changed when the user isn't silenced" do
    events =
      DiscourseEvent.track_events(:user_unsilenced) do
        expect(run_node).to include("changed" => false)
      end

    expect(events).to be_empty
  end

  it "lets only admins unsilence staff, and refuses actors who aren't staff", :aggregate_failures do
    other_moderator = Fabricate(:moderator, silenced_till: 1.day.from_now)
    member = Fabricate(:user)

    expect { run_node(username: other_moderator.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error(
        "unsilence_not_allowed",
        username: moderator.username,
        target: other_moderator.username,
      ),
    )
    expect { run_node(actor_username: member.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      moderation_error("unsilence_not_allowed", username: member.username, target: user.username),
    )
    expect(run_node(username: other_moderator.username, actor_username: admin.username)).to include(
      "changed" => true,
    )
  end
end
