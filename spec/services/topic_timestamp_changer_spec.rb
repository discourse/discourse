# frozen_string_literal: true

RSpec.describe TopicTimestampChanger do
  describe "#change!" do
    let(:old_timestamp) { Time.zone.now }
    let(:topic) { Fabricate(:topic, created_at: old_timestamp) }
    let!(:p1) { Fabricate(:post, topic: topic, created_at: old_timestamp) }
    let!(:p2) { Fabricate(:post, topic: topic, created_at: old_timestamp + 1.day) }

    context "when new timestamp is in the future" do
      let(:new_timestamp) { old_timestamp + 2.day }

      it "should raise the right error" do
        expect {
          TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change!
        }.to raise_error(TopicTimestampChanger::InvalidTimestampError)
      end
    end

    context "when new timestamp is in the past" do
      let(:new_timestamp) { old_timestamp - 2.day }

      it "changes the timestamp of the topic and opening post" do
        freeze_time
        TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change!

        topic.reload
        p1.reload
        p2.reload
        last_post_created_at = p2.created_at

        expect(topic.created_at).to eq_time(new_timestamp)
        expect(topic.updated_at).to eq_time(new_timestamp)
        expect(topic.bumped_at).to eq_time(last_post_created_at)
        expect(topic.last_posted_at).to eq_time(last_post_created_at)

        expect(p1.created_at).to eq_time(new_timestamp)
        expect(p1.updated_at).to eq_time(new_timestamp)

        expect(p2.created_at).to eq_time(new_timestamp + 1.day)
        expect(p2.updated_at).to eq_time(new_timestamp + 1.day)
      end

      context "when posts have timestamps in the future" do
        it "should set the new timestamp as the default timestamp" do
          new_timestamp = freeze_time

          p3 = Fabricate(:post, topic: topic, created_at: new_timestamp + 3.days)
          TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change!

          p3.reload

          expect(p3.created_at).to eq_time(new_timestamp)
          expect(p3.updated_at).to eq_time(new_timestamp)
        end
      end
    end

    it "deletes the stats cache" do
      Discourse.redis.set AdminDashboardData.stats_cache_key, "X"
      Discourse.redis.set About.stats_cache_key, "X"

      TopicTimestampChanger.new(topic: topic, timestamp: Time.zone.now.to_f).change!

      expect(Discourse.redis.get(AdminDashboardData.stats_cache_key)).to eq(nil)
      expect(Discourse.redis.get(About.stats_cache_key)).to eq(nil)
    end
  end
end
