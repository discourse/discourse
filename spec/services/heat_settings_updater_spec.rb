# frozen_string_literal: true

require 'rails_helper'

describe HeatSettingsUpdater do
  describe '#update' do
    subject(:update_settings) { HeatSettingsUpdater.update }

    def expect_default_values
      [:topic_views_heat, :topic_post_like_heat].each do |prefix|
        [:low, :medium, :high].each do |level|
          setting_name = "#{prefix}_#{level}"
          expect(SiteSetting.get(setting_name)).to eq(SiteSetting.defaults[setting_name])
        end
      end
    end

    it 'changes nothing on fresh install' do
      expect {
        update_settings
      }.to_not change { UserHistory.count }
      expect_default_values
    end

    context 'low activity' do
      let!(:hottest_topic1) { Fabricate(:topic, views: 3000, posts_count: 10, like_count: 2) }
      let!(:hottest_topic2) { Fabricate(:topic, views: 3000, posts_count: 10, like_count: 2) }
      let!(:warm_topic1) { Fabricate(:topic, views: 1500, posts_count: 10, like_count: 1) }
      let!(:warm_topic2) { Fabricate(:topic, views: 1500, posts_count: 10, like_count: 1) }
      let!(:warm_topic3) { Fabricate(:topic, views: 1500, posts_count: 10, like_count: 1) }
      let!(:lukewarm_topic1) { Fabricate(:topic, views: 800, posts_count: 10, like_count: 0) }
      let!(:lukewarm_topic2) { Fabricate(:topic, views: 800, posts_count: 10, like_count: 0) }
      let!(:lukewarm_topic3) { Fabricate(:topic, views: 800, posts_count: 10, like_count: 0) }
      let!(:lukewarm_topic4) { Fabricate(:topic, views: 800, posts_count: 10, like_count: 0) }
      let!(:cold_topic) { Fabricate(:topic, views: 100, posts_count: 10, like_count: 0) }

      it "doesn't make settings lower than defaults" do
        expect {
          update_settings
        }.to_not change { UserHistory.count }
        expect_default_values
      end

      it 'can set back down to minimum defaults' do
        [:low, :medium, :high].each do |level|
          SiteSetting.set("topic_views_heat_#{level}", 20_000)
          SiteSetting.set("topic_post_like_heat_#{level}", 5.0)
        end
        expect {
          update_settings
        }.to change { UserHistory.count }.by(6)
        expect_default_values
      end
    end

    context 'similar activity' do
      let!(:hottest_topic1) { Fabricate(:topic, views: 3530, posts_count: 100, like_count: 201) }
      let!(:hottest_topic2) { Fabricate(:topic, views: 3530, posts_count: 100, like_count: 201) }
      let!(:warm_topic1) { Fabricate(:topic, views: 2020, posts_count: 100, like_count: 99) }
      let!(:warm_topic2) { Fabricate(:topic, views: 2020, posts_count: 100, like_count: 99) }
      let!(:warm_topic3) { Fabricate(:topic, views: 2020, posts_count: 100, like_count: 99) }
      let!(:lukewarm_topic1) { Fabricate(:topic, views: 1010, posts_count: 100, like_count: 51) }
      let!(:lukewarm_topic2) { Fabricate(:topic, views: 1010, posts_count: 100, like_count: 51) }
      let!(:lukewarm_topic3) { Fabricate(:topic, views: 1010, posts_count: 100, like_count: 51) }
      let!(:lukewarm_topic4) { Fabricate(:topic, views: 1010, posts_count: 100, like_count: 51) }
      let!(:cold_topic) { Fabricate(:topic, views: 100, posts_count: 100, like_count: 1) }

      it "doesn't make small changes" do
        expect {
          update_settings
        }.to_not change { UserHistory.count }
        expect_default_values
      end
    end

    context 'increased activity' do
      let!(:hottest_topic1) { Fabricate(:topic, views: 10_100, posts_count: 100, like_count: 230) }
      let!(:hottest_topic2) { Fabricate(:topic, views: 10_012, posts_count: 100, like_count: 220) }
      let!(:warm_topic1) { Fabricate(:topic, views: 4020, posts_count: 99, like_count: 126) }
      let!(:warm_topic2) { Fabricate(:topic, views: 4010, posts_count: 99, like_count: 116) }
      let!(:warm_topic3) { Fabricate(:topic, views: 4005, posts_count: 99, like_count: 106) }
      let!(:lukewarm_topic1) { Fabricate(:topic, views: 2040, posts_count: 99, like_count: 84) }
      let!(:lukewarm_topic2) { Fabricate(:topic, views: 2030, posts_count: 99, like_count: 74) }
      let!(:lukewarm_topic3) { Fabricate(:topic, views: 2020, posts_count: 99, like_count: 64) }
      let!(:lukewarm_topic4) { Fabricate(:topic, views: 2002, posts_count: 99, like_count: 54) }
      let!(:cold_topic) { Fabricate(:topic, views: 100, posts_count: 100, like_count: 1) }

      it 'changes settings when difference is significant' do
        expect {
          update_settings
        }.to change { UserHistory.count }.by(6)
        expect(SiteSetting.topic_views_heat_high).to eq(10_000)
        expect(SiteSetting.topic_views_heat_medium).to eq(4000)
        expect(SiteSetting.topic_views_heat_low).to eq(2000)
        expect(SiteSetting.topic_post_like_heat_high).to eq(2.2)
        expect(SiteSetting.topic_post_like_heat_medium).to eq(1.07)
        expect(SiteSetting.topic_post_like_heat_low).to eq(0.55)
      end

      it "doesn't change settings when automatic_topic_heat_values is false" do
        SiteSetting.automatic_topic_heat_values = false
        expect {
          update_settings
        }.to_not change { UserHistory.count }
        expect_default_values
      end
    end
  end
end
