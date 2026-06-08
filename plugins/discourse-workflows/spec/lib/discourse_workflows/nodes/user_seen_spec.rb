# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserSeen::V1 do
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
    it "returns user data and first seen state" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)

      trigger = described_class.new(user)
      output = trigger.output

      expect(output[:user][:id]).to eq(user.id)
      expect(output[:user][:username]).to eq(user.username)
      expect(output[:seen][:first_seen]).to eq(true)
      expect(output[:seen][:current_seen_at]).to eq(seen_at.iso8601)
      expect(output[:seen][:previous_seen_at]).to eq(nil)
      expect(output[:seen][:seconds_since_previous_seen]).to eq(nil)
    end

    it "returns previous seen data" do
      current_seen_at = Time.zone.now
      previous_seen_at = current_seen_at - 2.days
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: current_seen_at)

      output = described_class.new(user, previous_seen_at).output

      expect(output[:seen][:first_seen]).to eq(false)
      expect(output[:seen][:current_seen_at]).to eq(current_seen_at.iso8601)
      expect(output[:seen][:previous_seen_at]).to eq(previous_seen_at.iso8601)
      expect(output[:seen][:seconds_since_previous_seen]).to eq(2.days.to_i)
    end
  end

  describe "#user_id" do
    it "returns the seen user ID" do
      expect(described_class.new(user).user_id).to eq(user.id)
    end
  end

  describe "#matches?" do
    it "matches first seen events by default" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)

      expect(described_class.new(user).matches?(trigger_context({}))).to eq(true)
    end

    it "does not match later seen events by default" do
      user.update_columns(first_seen_at: 2.days.ago, last_seen_at: Time.zone.now)

      expect(described_class.new(user, 2.hours.ago).matches?(trigger_context({}))).to eq(false)
    end

    it "matches every seen event when configured" do
      user.update_columns(first_seen_at: 2.days.ago, last_seen_at: Time.zone.now)

      expect(
        described_class.new(user, 2.hours.ago).matches?(
          trigger_context("trigger_on" => "every_time_seen"),
        ),
      ).to eq(true)
    end

    it "matches when the user has not been seen for more than the configured time" do
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)

      expect(
        described_class.new(user, 2.days.ago).matches?(
          trigger_context(
            "trigger_on" => "not_seen_for_more_than",
            "not_seen_for_amount" => 1,
            "not_seen_for_unit" => "days",
          ),
        ),
      ).to eq(true)
    end

    it "does not match when the user has been seen within the configured time" do
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)

      expect(
        described_class.new(user, 2.hours.ago).matches?(
          trigger_context(
            "trigger_on" => "not_seen_for_more_than",
            "not_seen_for_amount" => 1,
            "not_seen_for_unit" => "days",
          ),
        ),
      ).to eq(false)
    end

    it "matches when the user has never been seen before" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)

      expect(
        described_class.new(user).matches?(
          trigger_context(
            "trigger_on" => "not_seen_for_more_than",
            "not_seen_for_amount" => 1,
            "not_seen_for_unit" => "days",
          ),
        ),
      ).to eq(true)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
