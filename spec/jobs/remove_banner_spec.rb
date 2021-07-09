# frozen_string_literal: true

require 'rails_helper'

describe Jobs::RemoveBanner do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { topic.user }

  context 'topic is not bannered until' do
    it 'doesn’t enqueue a future job to remove it' do
      expect do
        topic.make_banner!(user)
      end.to change { Jobs::RemoveBanner.jobs.size }.by(0)
    end
  end

  context 'topic is bannered until' do
    context 'bannered_until is a valid date' do
      it 'enqueues a future job to remove it' do
        bannered_until = 5.days.from_now

        expect(topic.archetype).to eq(Archetype.default)

        expect do
          topic.make_banner!(user, bannered_until.to_s)
        end.to change { Jobs::RemoveBanner.jobs.size }.by(1)

        topic.reload
        expect(topic.archetype).to eq(Archetype.banner)

        job = Jobs::RemoveBanner.jobs[0]
        expect(Time.at(job['at'])).to be_within_one_minute_of(bannered_until)
        expect(job['args'][0]['topic_id']).to eq(topic.id)

        job['class'].constantize.new.perform(*job['args'])
        topic.reload
        expect(topic.archetype).to eq(Archetype.default)
      end
    end

    context 'bannered_until is an invalid date' do
      it 'doesn’t enqueue a future job to remove it' do
        expect do
          expect do
            topic.make_banner!(user, 'xxx')
          end.to raise_error(Discourse::InvalidParameters)
        end.to change { Jobs::RemoveBanner.jobs.size }.by(0)
      end
    end
  end
end
