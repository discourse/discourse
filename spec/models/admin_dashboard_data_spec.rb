# frozen_string_literal: true

RSpec.describe AdminDashboardData do
  after do
    AdminDashboardData.reset_problem_checks
    Discourse.redis.flushdb
  end

  describe "stats cache" do
    include_examples "stats cacheable"
  end

  describe "#problem_message_check" do
    let(:key) { "new_key" }

    after { described_class.clear_problem_message(key) }

    it "returns nil if message has not been added" do
      expect(described_class.problem_message_check(key)).to be_nil
    end

    it "returns a message if it was added" do
      described_class.add_problem_message(key)
      expect(described_class.problem_message_check(key)).to eq(
        I18n.t(key, base_path: Discourse.base_path),
      )
    end

    it "returns a message if it was added with an expiry" do
      described_class.add_problem_message(key, 300)
      expect(described_class.problem_message_check(key)).to eq(
        I18n.t(key, base_path: Discourse.base_path),
      )
    end
  end
end
