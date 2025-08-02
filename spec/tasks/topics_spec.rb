# frozen_string_literal: true

RSpec.describe "Post rake tasks" do
  fab!(:post) { Fabricate(:post, raw: "The quick brown fox jumps over the lazy dog") }
  let(:topic) { post.topic }
  let(:category) { topic.category }

  before { STDOUT.stubs(:write) }

  describe "topics:apply_autoclose" do
    it "should close topics silently" do
      category.auto_close_hours = 1
      category.save!

      original_bumped_at = topic.bumped_at

      freeze_time 2.hours.from_now

      invoke_rake_task("topics:apply_autoclose")

      topic.reload

      expect(topic.closed).to eq(true)
      expect(topic.bumped_at).to eq_time(original_bumped_at)
    end
  end
end
