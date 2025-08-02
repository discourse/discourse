# frozen_string_literal: true

RSpec.describe UserStatusSerializer do
  fab!(:user)
  fab!(:user_status) do
    Fabricate(
      :user_status,
      user: user,
      set_at: Time.parse("2023-09-29T02:20:00Z"),
      ends_at: Time.parse("2023-09-29T03:25:00Z"),
    )
  end

  describe "#ends_at" do
    it "is formatted as a ISO8601 timestamp" do
      serialized = described_class.new(user_status, scope: Guardian.new(user), root: false).as_json
      expect(serialized[:ends_at]).to eq("2023-09-29T03:25:00Z")
    end
  end
end
