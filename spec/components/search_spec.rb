# encoding: utf-8

require 'spec_helper'
require 'search'

describe Search do

  before do
    ActiveRecord::Base.observers.enable :search_observer
  end

  def first_of_type(results, type)
    return nil if results.blank?
    results.each do |r|
      return r[:results].first if r[:type] == type
    end
    nil
  end

  context 'post indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @topic = Fabricate(:topic, title: 'sam saffron test topic', category: @category)
      @post = Fabricate(:post, topic: @topic, raw: 'this <b>fun test</b> <img src="bla" title="my image">')
      @indexed = Topic.exec_sql("select search_data from posts_search where id = #{@post.id}").first["search_data"]
    end
    it "should include body in index" do
      @indexed.should =~ /fun/
    end
    it "should include title in index" do
      @indexed.should =~ /sam/
    end
    it "should include category in index" do
      @indexed.should =~ /america/
    end

    it "should pick up on title updates" do
      @topic.title = "harpi is the new title"
      @topic.save!
      @indexed = Topic.exec_sql("select search_data from posts_search where id = #{@post.id}").first["search_data"]

      @indexed.should =~ /harpi/
    end
  end

  context 'user indexing observer' do
    before do
      @user = Fabricate(:user, username: 'fred', name: 'bob jones')
      @indexed = User.exec_sql("select search_data from users_search where id = #{@user.id}").first["search_data"]
    end

    it "should pick up on username" do
      @indexed.should =~ /fred/
    end

    it "should pick up on name" do
      @indexed.should =~ /jone/
    end
  end

  context 'category indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @indexed = Topic.exec_sql("select search_data from categories_search where id = #{@category.id}").first["search_data"]
    end

    it "should pick up on name" do
      @indexed.should =~ /america/
    end

  end

  it 'returns something blank on a nil search' do
    ActiveRecord::Base.expects(:exec_sql).never
    Search.query(nil,nil).should be_blank
  end

  it 'does not search when the search term is too small' do
    ActiveRecord::Base.expects(:exec_sql).never
    Search.query('evil', nil,  nil, 5).should be_blank
  end

  it 'escapes non alphanumeric characters' do
    Search.query('foo :!$);}]>@\#\"\'', nil).should be_blank # There are at least three levels of sanitation for Search.query!
  end

  it 'works when given two terms with spaces' do
    lambda { Search.query('evil trout', nil) }.should_not raise_error
  end

  context 'users' do
    let!(:user) { Fabricate(:user) }
    let(:result) { first_of_type(Search.query('bruce', nil), 'user') }

    it 'returns a result' do
      result.should be_present
    end

    it 'has the display name as the title' do
      result['title'].should == user.username
    end

    it 'has the avatar_template is there so it can hand it to the client' do
      result['avatar_template'].should_not be_nil
    end

    it 'has a url for the record' do
      result['url'].should == "/users/#{user.username_lower}"
    end

  end

  context 'topics' do
    let(:topic) { Fabricate(:topic) }

    context 'searching the OP' do
      let!(:post) { Fabricate(:post, topic: topic, user: topic.user) }
      let(:result) { first_of_type(Search.query('hello', nil), 'topic') }

      it 'returns a result correctly' do
        result.should be_present
        result['title'].should == topic.title
        result['url'].should == topic.relative_url
      end
    end

    context "search for a topic by id" do
      let(:result) { first_of_type(Search.query(topic.id, nil, 'topic'), 'topic') }

      it 'returns the topic' do
        result.should be_present
        result['title'].should == topic.title
        result['url'].should == topic.relative_url
      end
    end

    context "search for a topic by url" do
      let(:result) { first_of_type(Search.query(topic.relative_url, nil, 'topic'), 'topic') }

      it 'returns the topic' do
        result.should be_present
        result['title'].should == topic.title
        result['url'].should == topic.relative_url
      end
    end

    context 'security' do
      let!(:post) { Fabricate(:post, topic: topic, user: topic.user) }
      def result(current_user)
        first_of_type(Search.query('hello', current_user), 'topic')
      end

      it 'secures results correctly' do
        category = Fabricate(:category)

        topic.category_id = category.id
        topic.save

        category.deny(:all)
        category.allow(Group[:staff])
        category.save

        result(nil).should_not be_present
        result(Fabricate(:user)).should_not be_present
        result(Fabricate(:admin)).should be_present

      end
    end

  end

  context 'cyrillic topic' do
    let!(:cyrillic_topic) { Fabricate(:topic) do
                                                user
                                                title { sequence(:title) { |i| "Тестовая запись #{i}" } }
                                              end
    }
    let!(:post) {Fabricate(:post, topic: cyrillic_topic, user: cyrillic_topic.user)}
    let(:result) { first_of_type(Search.query('запись',nil), 'topic') }

    it 'finds something when given cyrillic query' do
      result.should be_present
    end
  end

  context 'categories' do

    let!(:category) { Fabricate(:category) }
    def result
      first_of_type(Search.query('amazing', nil), 'category')
    end

    it 'returns the correct result' do
      r = result
      r.should be_present
      r['title'].should == category.name
      r['url'].should == "/category/#{category.slug}"

      category.deny(:all)
      category.save

      result.should_not be_present
    end

  end


  context 'type_filter' do

    let!(:user) { Fabricate(:user, username: 'amazing', email: 'amazing@amazing.com') }
    let!(:category) { Fabricate(:category, name: 'amazing category', user: user) }


    context 'user filter' do
      let(:results) { Search.query('amazing', nil, 'user') }

      it "returns a user result" do
        results.detect {|r| r[:type] == 'user'}.should be_present
        results.detect {|r| r[:type] == 'category'}.should be_blank
      end

    end

    context 'category filter' do
      let(:results) { Search.query('amazing', nil, 'category') }

      it "returns a user result" do
        results.detect {|r| r[:type] == 'user'}.should be_blank
        results.detect {|r| r[:type] == 'category'}.should be_present
      end

    end


  end

end

