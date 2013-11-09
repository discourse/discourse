require 'spec_helper'

describe ListController do

  # we need some data
  before do
    @user = Fabricate(:coding_horror)
    @post = Fabricate(:post, user: @user)

    # forces tests down some code paths
    SiteSetting.stubs(:top_menu).returns('latest,-video|new|unread|favorited|categories|category/beer')
  end

  describe 'indexes' do

    [:latest, :hot].each do |filter|
      context "#{filter}" do
        before { xhr :get, filter }
        it { should respond_with(:success) }
      end
    end

    [:favorited, :read, :posted, :unread, :new].each do |filter|
      context "#{filter}" do
        it { expect { xhr :get, filter }.to raise_error(Discourse::NotLoggedIn) }
      end
    end

    it 'allows users to filter on a set of topic ids' do
      p = create_post

      xhr :get, :latest, format: :json, topic_ids: "#{p.topic_id}"
      response.should be_success
      parsed = JSON.parse(response.body)
      parsed["topic_list"]["topics"].length.should == 1
    end

  end

  describe 'RSS feeds' do

    [:latest, :hot].each do |filter|

      it 'renders RSS' do
        get "#{filter}_feed", format: :rss
        response.should be_success
        response.content_type.should == 'application/rss+xml'
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

      context 'another category exists with a number at the beginning of its name' do
        # One category has another category's id at the beginning of its name
        let!(:other_category) { Fabricate(:category, name: "#{category.id} name") }

        before do
          xhr :get, :category, category: other_category.slug
        end

        it { should respond_with(:success) }

        it 'uses the correct category' do
          assigns(:category).should == other_category
        end
      end

      context 'a child category' do
        let(:sub_category) { Fabricate(:category, parent_category_id: category.id) }

        context 'when parent and child are requested' do
          before do
            xhr :get, :category, parent_category: category.slug, category: sub_category.slug
          end

          it { should respond_with(:success) }
        end

        context 'when child is requested with the wrong parent' do
          before do
            xhr :get, :category, parent_category: 'not_the_right_slug', category: sub_category.slug
          end

          it { should_not respond_with(:success) }
        end

        context 'when child is requested without a parent' do
          before do
            xhr :get, :category, category: sub_category.slug
          end

          it { should_not respond_with(:success) }
        end

      end

      describe 'feed' do
        it 'renders RSS' do
          get :category_feed, category: category.slug, format: :rss
          response.should be_success
          response.content_type.should == 'application/rss+xml'
        end
      end
    end
  end

  describe "topics_by" do
    let!(:user) { log_in }

    it "should respond with a list" do
      xhr :get, :topics_by, username: @user.username
      response.should be_success
    end
  end

  context "private_messages" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages, username: @user.username
      response.should be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages, username: @user.username
      response.should be_success
    end
  end

  context "private_messages_sent" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages_sent, username: @user.username
      response.should be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages_sent, username: @user.username
      response.should be_success
    end
  end

  context "private_messages_unread" do
    let!(:user) { log_in }

    it "raises an error when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(false)
      xhr :get, :private_messages_unread, username: @user.username
      response.should be_forbidden
    end

    it "succeeds when can_see_private_messages? is false " do
      Guardian.any_instance.expects(:can_see_private_messages?).returns(true)
      xhr :get, :private_messages_unread, username: @user.username
      response.should be_success
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
