require 'rails_helper'

describe ListController do

  # we need some data
  before do
    @user = Fabricate(:coding_horror)
    @post = Fabricate(:post, user: @user)

    # forces tests down some code paths
    SiteSetting.top_menu = 'latest,-video|new|unread|categories|category/beer'
  end

  describe 'indexes' do

    (Discourse.anonymous_filters - [:categories]).each do |filter|
      context "#{filter}" do
        before { get filter }
        it { is_expected.to respond_with(:success) }
      end
    end

    it 'allows users to filter on a set of topic ids' do
      p = create_post

      get :latest, format: :json, params: { topic_ids: "#{p.topic_id}" }
      expect(response).to be_success
      parsed = JSON.parse(response.body)
      expect(parsed["topic_list"]["topics"].length).to eq(1)
    end

    it "doesn't throw an error with a negative page" do
      get :top, params: { page: -1024 }
      expect(response).to be_success
    end
  end

  describe 'RSS feeds' do
    it 'renders latest RSS' do
      get "latest_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders top RSS' do
      get "top_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders all time top RSS' do
      get "top_all_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders yearly top RSS' do
      get "top_yearly_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders quarterly top RSS' do
      get "top_quarterly_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders monthly top RSS' do
      get "top_monthly_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders weekly top RSS' do
      get "top_weekly_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders daily top RSS' do
      get "top_daily_feed", format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

  context 'category' do

    context 'in a category' do
      let(:category) { Fabricate(:category) }

      context 'without access to see the category' do
        before do
          Guardian.any_instance.expects(:can_see?).with(category).returns(false)
          get :category_latest, params: { category: category.slug }
        end

        it { is_expected.not_to respond_with(:success) }
      end

      context 'with access to see the category' do
        before do
          get :category_latest, params: { category: category.slug }
        end

        it { is_expected.to respond_with(:success) }
      end

      context 'with a link that includes an id' do
        before do
          get :category_latest, params: {
            category: "#{category.id}-#{category.slug}"
          }
        end

        it { is_expected.to respond_with(:success) }
      end

      context 'with a link that has a parent slug, slug and id in its path' do
        let(:child_category) { Fabricate(:category, parent_category: category) }

        context "with valid slug" do
          before do
            get :category_latest, params: {
              parent_category: category.slug,
              category: child_category.slug,
              id: child_category.id
            }
          end

          it { is_expected.to redirect_to(child_category.url) }
        end

        context "with invalid slug" do
          before do
            get :category_latest, params: {
              parent_category: 'random slug',
              category: 'random slug',
              id: child_category.id
            }
          end

          it { is_expected.to redirect_to(child_category.url) }
        end
      end

      context 'another category exists with a number at the beginning of its name' do
        # One category has another category's id at the beginning of its name
        let!(:other_category) { Fabricate(:category, name: "#{category.id} name") }

        it 'uses the correct category' do
          get :category_latest,
            params: { category: other_category.slug },
            format: :json

          expect(response).to be_success

          body = JSON.parse(response.body)

          expect(body["topic_list"]["topics"].first["category_id"])
            .to eq(other_category.id)
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category, parent_category_id: category.id) }

        context 'when parent and child are requested' do
          before do
            get :category_latest, params: {
              parent_category: category.slug, category: sub_category.slug
            }
          end

          it { is_expected.to respond_with(:success) }
        end

        context 'when child is requested with the wrong parent' do
          before do
            get :category_latest, params: {
              parent_category: 'not_the_right_slug', category: sub_category.slug
            }
          end

          it { is_expected.not_to respond_with(:success) }
        end
      end

      describe 'feed' do
        it 'renders RSS' do
          get :category_feed, params: { category: category.slug }, format: :rss
          expect(response).to be_success
          expect(response.content_type).to eq('application/rss+xml')
        end
      end

      describe "category default views" do
        it "has a top default view" do
          category.update_attributes!(default_view: 'top', default_top_period: 'monthly')
          described_class.expects(:best_period_with_topics_for).with(anything, category.id, :monthly).returns(:monthly)
          get :category_default, params: { category: category.slug }
          expect(response).to be_success
        end

        it "has a default view of nil" do
          category.update_attributes!(default_view: nil)
          described_class.expects(:best_period_for).never
          get :category_default, params: { category: category.slug }
          expect(response).to be_success
        end

        it "has a default view of ''" do
          category.update_attributes!(default_view: '')
          described_class.expects(:best_period_for).never
          get :category_default, params: { category: category.slug }
          expect(response).to be_success
        end

        it "has a default view of latest" do
          category.update_attributes!(default_view: 'latest')
          described_class.expects(:best_period_for).never
          get :category_default, params: { category: category.slug }
          expect(response).to be_success
        end
      end

      describe "renders canonical tag" do
        render_views

        it 'for category default view' do
          get :category_default, params: { category: category.slug }
          expect(response).to be_success
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end

        it 'for category latest view' do
          get :category_latest, params: { category: category.slug }
          expect(response).to be_success
          expect(css_select("link[rel=canonical]").length).to eq(1)
        end
      end
    end
  end

  describe "topics_by" do
    let!(:user) { log_in }

    it "should respond with a list" do
      get :topics_by, params: { username: @user.username }
      expect(response).to be_success
    end
  end

  context "private_messages" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      get :private_messages, params: { username: @user.username }
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      get :private_messages, params: { username: @user.username }
      expect(response).to be_success
    end
  end

  context "private_messages_sent" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      get :private_messages_sent, params: { username: @user.username }
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      get :private_messages_sent, params: { username: @user.username }
      expect(response).to be_success
    end
  end

  context "private_messages_unread" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      get :private_messages_unread, params: { username: @user.username }
      expect(response).to be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      get :private_messages_unread, params: { username: @user.username }
      expect(response).to be_success
    end
  end

  context 'read' do
    it 'raises an error when not logged in' do
      expect { get :read }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        log_in_user(@user)
        get :read
      end

      it { is_expected.to respond_with(:success) }
    end
  end

  describe "best_periods_for" do

    it "returns yearly for more than 180 days" do
      expect(ListController.best_periods_for(nil, :all)).to eq([:yearly])
      expect(ListController.best_periods_for(180.days.ago, :all)).to eq([:yearly])
    end

    it "includes monthly when less than 180 days and more than 35 days" do
      (35...180).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:monthly, :yearly])
      end
    end

    it "includes weekly when less than 35 days and more than 8 days" do
      (8...35).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:weekly, :monthly, :yearly])
      end
    end

    it "includes daily when less than 8 days" do
      (0...8).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :all)).to eq([:daily, :weekly, :monthly, :yearly])
      end
    end

    it "returns default even for more than 180 days" do
      expect(ListController.best_periods_for(nil, :monthly)).to eq([:monthly, :yearly])
      expect(ListController.best_periods_for(180.days.ago, :monthly)).to eq([:monthly, :yearly])
    end

    it "returns default even when less than 180 days and more than 35 days" do
      (35...180).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :weekly)).to eq([:weekly, :monthly, :yearly])
      end
    end

    it "returns default even when less than 35 days and more than 8 days" do
      (8...35).each do |date|
        expect(ListController.best_periods_for(date.days.ago, :daily)).to eq([:daily, :weekly, :monthly, :yearly])
      end
    end

    it "doesn't return default when set to all" do
      expect(ListController.best_periods_for(nil, :all)).to eq([:yearly])
    end

    it "doesn't return value twice when matches default" do
      expect(ListController.best_periods_for(nil, :yearly)).to eq([:yearly])
    end
  end

  describe "categories suppression" do
    let(:category_one) { Fabricate(:category) }
    let(:sub_category) { Fabricate(:category, parent_category: category_one, suppress_from_homepage: true) }
    let!(:topic_in_sub_category) { Fabricate(:topic, category: sub_category) }

    let(:category_two) { Fabricate(:category, suppress_from_homepage: true) }
    let!(:topic_in_category_two) { Fabricate(:topic, category: category_two) }

    it "suppresses categories from the homepage" do
      get SiteSetting.homepage, format: :json
      expect(response).to be_success

      topic_titles = JSON.parse(response.body)["topic_list"]["topics"].map { |t| t["title"] }
      expect(topic_titles).not_to include(topic_in_sub_category.title, topic_in_category_two.title)
    end

    it "does not suppress" do
      get SiteSetting.homepage, params: { category: category_one.id }, format: :json
      expect(response).to be_success

      topic_titles = JSON.parse(response.body)["topic_list"]["topics"].map { |t| t["title"] }
      expect(topic_titles).to include(topic_in_sub_category.title)
    end

  end

  describe "safe mode" do
    render_views

    it "handles safe mode" do
      get :latest
      expect(response.body).to match(/plugin\.js/)
      expect(response.body).to match(/plugin-third-party\.js/)

      get :latest, params: { safe_mode: "no_plugins" }
      expect(response.body).not_to match(/plugin\.js/)
      expect(response.body).not_to match(/plugin-third-party\.js/)

      get :latest, params: { safe_mode: "only_official" }
      expect(response.body).to match(/plugin\.js/)
      expect(response.body).not_to match(/plugin-third-party\.js/)

    end

  end

end
