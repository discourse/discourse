# frozen_string_literal: true

require 'rails_helper'
require 'introduction_updater'

describe IntroductionUpdater do
  describe "#get_summary" do
    subject { IntroductionUpdater.new(Fabricate(:admin)) }

    let(:welcome_post_raw) { "lorem ipsum" }
    let(:welcome_topic) do
      topic = Fabricate(:topic)
      Fabricate(:post, topic: topic, raw: welcome_post_raw, post_number: 1)
      topic
    end

    it "finds the welcome topic by site setting" do
      SiteSetting.welcome_topic_id = welcome_topic.id
      expect(subject.get_summary).to eq(welcome_post_raw)
    end

    context "without custom field" do
      it "finds the welcome topic by slug using the default locale" do
        I18n.locale = :de
        welcome_topic.title = I18n.t("discourse_welcome_topic.title")
        welcome_topic.save!

        expect(subject.get_summary).to eq(welcome_post_raw)
      end

      it "finds the welcome topic by slug using the English locale" do
        welcome_topic.title = I18n.t("discourse_welcome_topic.title", locale: :en)
        welcome_topic.save!
        I18n.locale = :de

        expect(subject.get_summary).to eq(welcome_post_raw)
      end

      it "doesn't find the topic when slug_generation_method is set to 'none'" do
        SiteSetting.slug_generation_method = :none
        welcome_topic.title = I18n.t("discourse_welcome_topic.title")
        welcome_topic.save!

        expect(subject.get_summary).to be_blank
      end

      it "finds the oldest globally pinned topic" do
        welcome_topic.update_columns(pinned_at: Time.zone.now, pinned_globally: true)

        expect(subject.get_summary).to eq(welcome_post_raw)
      end

      it "doesn't find the topic when there is no globally pinned topic or a topic with the correct slug" do
        expect(subject.get_summary).to be_blank
      end
    end
  end
end
