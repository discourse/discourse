# frozen_string_literal: true

require 'rails_helper'

describe SiteSetting do

  describe 'topic_title_length' do
    it 'returns a range of min/max topic title length' do
      expect(SiteSetting.topic_title_length).to eq(
        (SiteSetting.defaults[:min_topic_title_length]..SiteSetting.defaults[:max_topic_title_length])
      )
    end
  end

  describe 'post_length' do
    it 'returns a range of min/max post length' do
      expect(SiteSetting.post_length).to eq(SiteSetting.defaults[:min_post_length]..SiteSetting.defaults[:max_post_length])
    end
  end

  describe 'first_post_length' do
    it 'returns a range of min/max first post length' do
      expect(SiteSetting.first_post_length).to eq(SiteSetting.defaults[:min_first_post_length]..SiteSetting.defaults[:max_post_length])
    end
  end

  describe 'private_message_title_length' do
    it 'returns a range of min/max pm topic title length' do
      expect(SiteSetting.private_message_title_length).to eq(SiteSetting.defaults[:min_personal_message_title_length]..SiteSetting.defaults[:max_topic_title_length])
    end
  end

  describe 'in test we do some judo to ensure SiteSetting is always reset between tests' do

    it 'is always the correct default' do
      expect(SiteSetting.contact_email).to eq('')
    end

    it 'sets a setting' do
      SiteSetting.contact_email = 'sam@sam.com'
    end

    it 'is always the correct default' do
      expect(SiteSetting.contact_email).to eq('')
    end
  end

  describe "anonymous_homepage" do
    it "returns latest" do
      expect(SiteSetting.anonymous_homepage).to eq('latest')
    end
  end

  describe "top_menu" do
    describe "validations" do
      it "always demands latest" do
        expect do
          SiteSetting.top_menu = 'categories'
        end.to raise_error(Discourse::InvalidParameters)
      end

      it "does not allow random text" do
        expect do
          SiteSetting.top_menu = 'latest|random'
        end.to raise_error(Discourse::InvalidParameters)
      end
    end

    describe "items" do
      let(:items) { SiteSetting.top_menu_items }

      it 'returns TopMenuItem objects' do
        expect(items[0]).to be_kind_of(TopMenuItem)
      end
    end

    describe "homepage" do
      it "has homepage" do
        SiteSetting.top_menu = "bookmarks|latest"
        expect(SiteSetting.homepage).to eq('bookmarks')
      end
    end
  end

  describe "min_redirected_to_top_period" do

    context "has_enough_top_topics" do

      before do
        SiteSetting.topics_per_period_in_top_page = 2
        SiteSetting.top_page_default_timeframe = 'daily'

        2.times do
          TopTopic.create!(daily_score: 2.5)
        end

        TopTopic.refresh!
      end

      it "should_return_a_time_period" do
        expect(SiteSetting.min_redirected_to_top_period(1.days.ago)).to eq(:daily)
      end

    end

    context "does_not_have_enough_top_topics" do

      before do
        SiteSetting.topics_per_period_in_top_page = 20
        SiteSetting.top_page_default_timeframe = 'daily'
        TopTopic.refresh!
      end

      it "should_return_a_time_period" do
        expect(SiteSetting.min_redirected_to_top_period(1.days.ago)).to eq(nil)
      end

    end

  end

  describe "scheme" do
    before do
      SiteSetting.force_https = true
    end

    it "returns http when ssl is disabled" do
      SiteSetting.force_https = false
      expect(SiteSetting.scheme).to eq("http")
    end

    it "returns https when using ssl" do
      expect(SiteSetting.scheme).to eq("https")
    end
  end

  context "shared_drafts_enabled?" do
    it "returns false by default" do
      expect(SiteSetting.shared_drafts_enabled?).to eq(false)
    end

    it "returns false when the category is uncategorized" do
      SiteSetting.shared_drafts_category = SiteSetting.uncategorized_category_id
      expect(SiteSetting.shared_drafts_enabled?).to eq(false)
    end

    it "returns true when the category is valid" do
      SiteSetting.shared_drafts_category = Fabricate(:category).id
      expect(SiteSetting.shared_drafts_enabled?).to eq(true)
    end
  end

  context 'deprecated site settings' do
    before do
      SiteSetting.force_https = true
      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after do
      Rails.logger = @orig_logger
    end

    it 'should act as a proxy to the new methods' do
      begin
        original_settings = SiteSettings::DeprecatedSettings::SETTINGS
        SiteSettings::DeprecatedSettings::SETTINGS.clear

        SiteSettings::DeprecatedSettings::SETTINGS.push([
          'use_https', 'force_https', true, '0.0.1'
        ])

        SiteSetting.setup_deprecated_methods

        expect do
          expect(SiteSetting.use_https).to eq(true)
          expect(SiteSetting.use_https?).to eq(true)
        end.to change { @fake_logger.warnings.count }.by(2)

        expect do
          expect(SiteSetting.use_https(warn: false))
        end.to_not change { @fake_logger.warnings }

        SiteSetting.use_https = false

        expect(SiteSetting.force_https).to eq(false)
        expect(SiteSetting.force_https?).to eq(false)
      ensure
        SiteSettings::DeprecatedSettings::SETTINGS.clear

        SiteSettings::DeprecatedSettings::SETTINGS.concat(
          original_settings
        )
      end
    end
  end

  describe 'cached settings' do
    it 'should recalcualte cached setting when dependent settings are changed' do
      SiteSetting.attachment_filename_blacklist = 'foo'
      expect(SiteSetting.attachment_filename_blacklist_regex).to eq(/foo/)

      SiteSetting.attachment_filename_blacklist = 'foo|bar'
      expect(SiteSetting.attachment_filename_blacklist_regex).to eq(/foo|bar/)
    end
  end
end
