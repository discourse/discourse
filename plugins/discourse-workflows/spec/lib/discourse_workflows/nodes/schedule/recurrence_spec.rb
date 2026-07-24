# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Schedule::Recurrence do
  describe ".due?" do
    it "requires an exact modular interval match" do
      recurrence = { activated: true, index: 0, interval_size: 3, type_interval: "days" }
      last_day = Time.utc(2026, 3, 18, 9, 0).yday

      expect(
        described_class.due?(recurrence, [last_day], Time.utc(2026, 3, 22, 9, 0), "UTC"),
      ).to be(false)
      expect(
        described_class.due?(recurrence, [last_day], Time.utc(2026, 3, 21, 9, 0), "UTC"),
      ).to be(true)
    end
  end
end
