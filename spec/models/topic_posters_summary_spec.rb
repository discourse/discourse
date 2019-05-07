# frozen_string_literal: true

require 'rails_helper'

describe TopicPostersSummary do
  describe '#summary' do
    let!(:topic_creator)  { Fabricate(:user) }

    context "when there are no other posters" do
      let!(:topic) do
        Fabricate(:topic,
          user: topic_creator,
        )
      end

      let!(:summary) { described_class.new(topic).summary }

      it 'contains only the topic creator' do
        expect(summary.count).to eq 1

        summary.first.tap do |topic_poster|
          expect(topic_poster.user).to eq topic_creator
          expect(topic_poster.description).to eq(
            "#{I18n.t(:original_poster)}, #{I18n.t(:most_recent_poster)}"
          )
        end
      end
    end

    context 'when the last poster is also the topic creator' do
      fab!(:featured_user1) { Fabricate(:user) }

      let!(:topic) do
        Fabricate(:topic,
          user: topic_creator,
          last_poster: topic_creator,
          featured_user1: featured_user1,
        )
      end

      let!(:summary) { described_class.new(topic).summary }

      it 'keeps the topic creator at the front of the summary' do
        expect(summary.map(&:user)).to eq([
          topic_creator,
          featured_user1
        ])
      end
    end

    context 'when the topic has many posters' do
      let!(:last_poster)    { Fabricate(:user) }
      fab!(:featured_user1) { Fabricate(:user) }
      fab!(:featured_user2) { Fabricate(:user) }
      fab!(:featured_user3) { Fabricate(:user) }
      fab!(:featured_user4) { Fabricate(:user) }

      let!(:topic) do
        Fabricate(:topic,
          user: topic_creator,
          last_poster: last_poster,
          featured_user1: featured_user1,
          featured_user2: featured_user2,
          featured_user3: featured_user3,
          featured_user4: featured_user4
        )
      end

      let!(:summary) { described_class.new(topic).summary }

      it 'contains only five posters with latest poster at the end' do
        expect(summary.map(&:user)).to eq([
          topic_creator,
          featured_user1, featured_user2, featured_user3,
          last_poster
        ])
        # If more than one user, attach the latest class
        expect(summary.last.extras).to eq 'latest'
      end
    end
  end
end
