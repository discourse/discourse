# frozen_string_literal: true

require 'rails_helper'

describe TopicTimestampChanger do
  describe "change!" do
    let(:old_timestamp) { Time.zone.now }
    let(:topic) { Fabricate(:topic, created_at: old_timestamp) }
    let!(:p1) { Fabricate(:post, topic: topic, created_at: old_timestamp) }
    let!(:p2) { Fabricate(:post, topic: topic, created_at: old_timestamp + 1.day) }

    context 'new timestamp is in the future' do
      let(:new_timestamp) { old_timestamp + 2.day }

      it 'should raise the right error' do
        expect { TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change! }
          .to raise_error(TopicTimestampChanger::InvalidTimestampError)
      end
    end

    context 'new timestamp is in the past' do
      let(:new_timestamp) { old_timestamp - 2.day }

      it 'changes the timestamp of the topic and opening post' do
        freeze_time
        TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change!

        topic.reload
        [:created_at, :updated_at, :bumped_at].each do |column|
          expect(topic.public_send(column)).to be_within(1.second).of(new_timestamp)
        end

        p1.reload
        [:created_at, :updated_at].each do |column|
          expect(p1.public_send(column)).to be_within(1.second).of(new_timestamp)
        end

        p2.reload
        [:created_at, :updated_at].each do |column|
          expect(p2.public_send(column)).to be_within(1.second).of(new_timestamp + 1.day)
        end

        expect(topic.last_posted_at).to be_within(1.second).of(p2.reload.created_at)
      end

      describe 'when posts have timestamps in the future' do
        let(:new_timestamp) { Time.zone.now }
        let(:p3) { Fabricate(:post, topic: topic, created_at: new_timestamp + 3.day) }

        it 'should set the new timestamp as the default timestamp' do
          freeze_time

          p3

          TopicTimestampChanger.new(topic: topic, timestamp: new_timestamp.to_f).change!

          p3.reload

          [:created_at, :updated_at].each do |column|
            expect(p3.public_send(column)).to be_within(1.second).of(new_timestamp)
          end
        end
      end
    end

    it 'deletes the stats cache' do
      Discourse.redis.set AdminDashboardData.stats_cache_key, "X"
      Discourse.redis.set About.stats_cache_key, "X"

      TopicTimestampChanger.new(topic: topic, timestamp: Time.zone.now.to_f).change!

      expect(Discourse.redis.get(AdminDashboardData.stats_cache_key)).to eq(nil)
      expect(Discourse.redis.get(About.stats_cache_key)).to eq(nil)
    end
  end
end
