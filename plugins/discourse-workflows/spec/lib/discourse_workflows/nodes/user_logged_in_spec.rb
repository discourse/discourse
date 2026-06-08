# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserLoggedIn::V1 do
  fab!(:user)

  describe "#valid?" do
    it "returns true when user is present" do
      trigger = described_class.new(user)
      expect(trigger).to be_valid
    end

    it "returns false when user is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns user data and first login state" do
      trigger = described_class.new(user)
      output = trigger.output

      expect(output[:user][:id]).to eq(user.id)
      expect(output[:user][:username]).to eq(user.username)
      expect(output[:login][:first_login]).to eq(true)
      expect(output[:login][:previous_seen_at]).to eq(nil)
      expect(output[:login][:seconds_since_previous_seen]).to eq(nil)
    end

    it "returns previous seen data" do
      user.update_last_seen!(2.days.ago)
      output = described_class.new(user).output

      expect(output[:login][:first_login]).to eq(false)
      expect(output[:login][:previous_seen_at]).to eq(user.last_seen_at.iso8601)
      expect(output[:login][:seconds_since_previous_seen]).to be >= 2.days.to_i
    end
  end

  describe "#user_id" do
    it "returns the logged-in user ID" do
      expect(described_class.new(user).user_id).to eq(user.id)
    end
  end

  describe "#matches?" do
    it "matches first logins by default" do
      expect(described_class.new(user).matches?(trigger_context({}))).to eq(true)
    end

    it "does not match later logins by default" do
      user.update_last_seen!(2.days.ago)

      expect(described_class.new(user).matches?(trigger_context({}))).to eq(false)
    end

    it "matches every login when configured" do
      user.update_last_seen!(2.days.ago)

      expect(
        described_class.new(user).matches?(trigger_context("trigger_on" => "every_login")),
      ).to eq(true)
    end

    it "matches when previous visit is older than the configured time" do
      user.update_last_seen!(2.days.ago)

      expect(
        described_class.new(user).matches?(
          trigger_context(
            "trigger_on" => "previous_visit_more_than",
            "previous_visit_amount" => 1,
            "previous_visit_unit" => "days",
          ),
        ),
      ).to eq(true)
    end

    it "does not match when previous visit is newer than the configured time" do
      user.update_last_seen!(2.hours.ago)

      expect(
        described_class.new(user).matches?(
          trigger_context(
            "trigger_on" => "previous_visit_more_than",
            "previous_visit_amount" => 1,
            "previous_visit_unit" => "days",
          ),
        ),
      ).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
