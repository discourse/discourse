require 'rails_helper'
require_dependency 'site_setting'
require_dependency 'site_setting_extension'

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

    describe '#use_https' do
      before do
        SiteSetting.force_https = true
      end

      it 'should act as a proxy to the new methods' do
        expect(SiteSetting.use_https).to eq(true)
        expect(SiteSetting.use_https?).to eq(true)

        SiteSetting.use_https = false

        expect(SiteSetting.force_https).to eq(false)
        expect(SiteSetting.force_https?).to eq(false)
      end
    end

    describe 'rename private message to personal message' do
      before do
        SiteSetting.min_personal_message_title_length = 15
        SiteSetting.enable_personal_messages = true
        SiteSetting.personal_email_time_window_seconds = 15
        SiteSetting.max_personal_messages_per_day = 15
        SiteSetting.default_email_personal_messages = true
      end

      it 'should act as a proxy to the new methods' do
        expect(SiteSetting.min_private_message_title_length).to eq(15)
        SiteSetting.min_private_message_title_length = 5
        expect(SiteSetting.min_personal_message_title_length).to eq(5)

        expect(SiteSetting.enable_private_messages).to eq(true)
        SiteSetting.enable_private_messages = false
        expect(SiteSetting.enable_personal_messages).to eq(false)

        expect(SiteSetting.private_email_time_window_seconds).to eq(15)
        SiteSetting.private_email_time_window_seconds = 5
        expect(SiteSetting.personal_email_time_window_seconds).to eq(5)

        expect(SiteSetting.max_private_messages_per_day).to eq(15)
        SiteSetting.max_private_messages_per_day = 5
        expect(SiteSetting.max_personal_messages_per_day).to eq(5)

        expect(SiteSetting.default_email_private_messages).to eq(true)
        SiteSetting.default_email_private_messages = false
        expect(SiteSetting.default_email_personal_messages).to eq(false)
      end
    end
  end
end
