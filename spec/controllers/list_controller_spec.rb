require 'spec_helper'

describe ListController do

  # we need some data
  before do
    @user = Fabricate(:coding_horror)
    @post = Fabricate(:post, user: @user)
  end

  describe 'indexes' do

    [:latest, :hot].each do |filter|
      context '#{filter}' do
        before { xhr :get, filter }
        it { should respond_with(:success) }
      end
    end

    [:favorited, :read, :posted, :unread, :new].each do |filter|
      context '#{filter}' do
        it { expect { xhr :get, filter }.to raise_error(Discourse::NotLoggedIn) }
      end
    end

  end

  context 'category' do

    context 'in a category' do
      let(:category) { Fabricate(:category) }

      it "raises an invalid access error when the user can't see the category" do
        Guardian.any_instance.expects(:can_see?).with(category).returns(false)
        xhr :get, :category, category: category.slug
        response.should be_forbidden
      end

      context 'with access to see the category' do
        before do
          xhr :get, :category, category: category.slug
        end

        it { should respond_with(:success) }
      end

      context 'with a link that includes an id' do
        before do
          xhr :get, :category, category: "#{category.id}-#{category.slug}"
        end

        it { should respond_with(:success) }
      end

      describe 'feed' do
        it 'renders RSS' do
          get :category_feed, category: category.slug, format: :rss
          response.should be_success
          response.content_type.should == 'application/rss+xml'
        end
      end

    end

    context 'uncategorized' do

      it "doesn't check access to see the category, since we didn't provide one" do
        Guardian.any_instance.expects(:can_see?).never
        xhr :get, :category, category: SiteSetting.uncategorized_name
      end

      it "responds with success" do
        xhr :get, :category, category: SiteSetting.uncategorized_name
        response.should be_success
      end

    end

  end

  context 'hot' do
    before do
      xhr :get, :hot
    end

    it { should respond_with(:success) }
  end

  context 'favorited' do
    it 'raises an error when not logged in' do
      lambda { xhr :get, :favorited }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        log_in_user(@user)
        xhr :get, :favorited
      end

      it { should respond_with(:success) }
    end
  end


  context 'read' do
    it 'raises an error when not logged in' do
      lambda { xhr :get, :read }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'when logged in' do
      before do
        log_in_user(@user)
        xhr :get, :read
      end

      it { should respond_with(:success) }
    end
  end

end
