# encoding: utf-8

require 'spec_helper'
require 'search'

describe Search do

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
      @topic = Fabricate(:topic, title: 'sam test topic', category: @category)
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
    Search.query(nil).should be_blank
  end

  it 'does not search when the search term is too small' do
    ActiveRecord::Base.expects(:exec_sql).never
    Search.query('evil', nil, 5).should be_blank
  end

  it 'escapes non alphanumeric characters' do
    Search.query('foo :!$);}]>@\#\"\'').should be_blank # There are at least three levels of sanitation for Search.query!
  end

  it 'works when given two terms with spaces' do
    lambda { Search.query('evil trout') }.should_not raise_error
  end

  context 'users' do
    let!(:user) { Fabricate(:user) }
    let(:result) { first_of_type(Search.query('bruce'), 'user') }

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
    let!(:topic) { Fabricate(:topic) }

    context 'searching the OP' do

      let!(:post) { Fabricate(:post, topic: topic, user: topic.user) }
      let(:result) { first_of_type(Search.query('hello'), 'topic') }

      it 'returns a result' do
        result.should be_present
      end

      it 'has the topic title' do
        result['title'].should == topic.title
      end

      it 'has a url for the post' do
        result['url'].should == topic.relative_url
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
    let(:result) { first_of_type(Search.query('запись'), 'topic') }

    it 'finds something when given cyrillic query' do
      result.should be_present
    end
  end

  context 'categories' do

    let!(:category) { Fabricate(:category) }
    let(:result) { first_of_type(Search.query('amazing'), 'category') }

    it 'returns a result' do
      result.should be_present
    end

    it 'has the category name' do
      result['title'].should == category.name
    end

    it 'has a url for the topic' do
      result['url'].should == "/category/#{category.slug}"
    end

  end


  context 'type_filter' do

    let!(:user) { Fabricate(:user, username: 'amazing', email: 'amazing@amazing.com') }
    let!(:category) { Fabricate(:category, name: 'amazing category', user: user) }


    context 'user filter' do
      let(:results) { Search.query('amazing', 'user') }

      it "returns a user result" do
        results.detect {|r| r[:type] == 'user'}.should be_present
      end

      it "returns no category results" do
        results.detect {|r| r[:type] == 'category'}.should be_blank
      end

    end

    context 'category filter' do
      let(:results) { Search.query('amazing', 'category') }

      it "returns a user result" do
        results.detect {|r| r[:type] == 'user'}.should be_blank
      end

      it "returns no category results" do
        results.detect {|r| r[:type] == 'category'}.should be_present
      end

    end


  end

end

