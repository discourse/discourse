# encoding: utf-8

require 'spec_helper'
require_dependency 'search'

describe Search do

  class TextHelper
    extend ActionView::Helpers::TextHelper
  end

  before do
    ActiveRecord::Base.observers.enable :search_observer
  end

  context 'post indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @topic = Fabricate(:topic, title: 'sam saffron test topic', category: @category)
      @post = Fabricate(:post, topic: @topic, raw: 'this <b>fun test</b> <img src="bla" title="my image">')
      @indexed = @post.post_search_data.search_data
    end

    it "should index correctly" do
      @indexed.should =~ /fun/
      @indexed.should =~ /sam/
      @indexed.should =~ /america/

      @topic.title = "harpi is the new title"
      @topic.save!
      @post.post_search_data.reload

      @indexed = @post.post_search_data.search_data

      @indexed.should =~ /harpi/
    end
  end

  context 'user indexing observer' do
    before do
      @user = Fabricate(:user, username: 'fred', name: 'bob jones')
      @indexed = @user.user_search_data.search_data
    end

    it "should pick up on data" do
      @indexed.should =~ /fred/
      @indexed.should =~ /jone/
    end
  end

  context 'category indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @indexed = @category.category_search_data.search_data
    end

    it "should pick up on name" do
      @indexed.should =~ /america/
    end

  end

  it 'does not search when the search term is too small' do
    ActiveRecord::Base.expects(:exec_sql).never
    Search.execute('evil', min_search_term_length: 5)
  end

  it 'escapes non alphanumeric characters' do
    Search.execute('foo :!$);}]>@\#\"\'').posts.length.should == 0 # There are at least three levels of sanitation for Search.query!
  end

  it "doesn't raise an error when single quotes are present" do
    Search.execute("'hello' world").posts.length.should == 0 # There are at least three levels of sanitation for Search.query!
  end

  it 'works when given two terms with spaces' do
    lambda { Search.execute('evil trout') }.should_not raise_error
  end

  context 'users' do
    let!(:user) { Fabricate(:user) }
    let(:result) { Search.execute('bruce', type_filter: 'user') }

    it 'returns a result' do
      result.users.length.should == 1
      result.users[0].id.should == user.id
    end
  end

  context 'inactive users' do
    let!(:inactive_user) { Fabricate(:inactive_user, active: false) }
    let(:result) { Search.execute('bruce') }

    it 'does not return a result' do
      result.users.length.should == 0
    end
  end

  context 'topics' do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic}


    context 'search within topic' do

      def new_post(raw, topic)
        Fabricate(:post, topic: topic, topic_id: topic.id, user: topic.user, raw: raw)
      end

      it 'displays multiple results within a topic' do

        topic = Fabricate(:topic)
        topic2 = Fabricate(:topic)

        new_post('this is the other post I am posting', topic2)
        new_post('this is my fifth post I am posting', topic2)

        post1 = new_post('this is the other post I am posting', topic)
        post2 = new_post('this is my first post I am posting', topic)
        post3 = new_post('this is a real long and complicated bla this is my second post I am Posting birds
                         with more stuff bla bla', topic)
        post4 = new_post('this is my fourth post I am posting', topic)

        # update posts_count
        topic.reload

        results = Search.execute('posting', search_context: post1.topic)
        results.posts.map(&:id).should == [post1.id, post2.id, post3.id, post4.id]

        # stop words should work
        results = Search.execute('this', search_context: post1.topic)
        results.posts.length.should == 4

      end
    end

    context 'searching the OP' do
      let!(:post) { Fabricate(:post_with_long_raw_content) }
      let(:result) { Search.execute('hundred', type_filter: 'topic', include_blurbs: true) }

      it 'returns a result correctly' do
        result.posts.length.should == 1
        result.posts[0].id.should == post.id
      end
    end

    context 'searching for a post' do
      let!(:reply) { Fabricate(:basic_reply, topic: topic, user: topic.user) }
      let(:result) { Search.execute('quotes', type_filter: 'topic', include_blurbs: true) }

      it 'returns the post' do
        result.should be_present
        result.posts.length.should == 1
        p = result.posts[0]
        p.topic.id.should == topic.id
        p.id.should == reply.id
        result.blurb(p).should == "this reply has no quotes"
      end
    end

    context "search for a topic by id" do
      let(:result) { Search.execute(topic.id, type_filter: 'topic', search_for_id: true, min_search_term_length: 1) }

      it 'returns the topic' do
        result.posts.length.should == 1
        result.posts.first.id.should == post.id
      end
    end

    context "search for a topic by url" do
      let(:result) { Search.execute(topic.relative_url, search_for_id: true, type_filter: 'topic')}

      it 'returns the topic' do
        result.posts.length.should == 1
        result.posts.first.id.should == post.id
      end
    end

    context 'security' do

      def result(current_user)
        Search.execute('hello', guardian: Guardian.new(current_user))
      end

      it 'secures results correctly' do
        category = Fabricate(:category)

        topic.category_id = category.id
        topic.save

        category.set_permissions(:staff => :full)
        category.save

        result(nil).posts.should_not be_present
        result(Fabricate(:user)).posts.should_not be_present
        result(Fabricate(:admin)).posts.should be_present

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
    let(:result) { Search.execute('запись') }

    it 'finds something when given cyrillic query' do
      result.posts.should be_present
    end
  end

  context 'categories' do

    let!(:category) { Fabricate(:category) }
    def search
      Search.execute(category.name)
    end

    it 'returns the correct result' do
      search.categories.should be_present

      category.set_permissions({})
      category.save

      search.categories.should_not be_present
    end

  end


  context 'type_filter' do

    let!(:user) { Fabricate(:user, username: 'amazing', email: 'amazing@amazing.com') }
    let!(:category) { Fabricate(:category, name: 'amazing category', user: user) }


    context 'user filter' do
      let(:results) { Search.execute('amazing', type_filter: 'user') }

      it "returns a user result" do
        results.categories.length.should == 0
        results.posts.length.should == 0
        results.users.length.should == 1
      end

    end

    context 'category filter' do
      let(:results) { Search.execute('amazing', type_filter: 'category') }

      it "returns a category result" do
        results.categories.length.should == 1
        results.posts.length.should == 0
        results.users.length.should == 0
      end

    end

  end

  context 'search_context' do

    it 'can find a user when using search context' do

      coding_horror = Fabricate(:coding_horror)
      post = Fabricate(:post)

      Fabricate(:post, user: coding_horror)

      result = Search.execute('hello', search_context: post.user)

      result.posts.first.topic_id = post.topic_id
      result.posts.length.should == 1
    end

    it 'can use category as a search context' do
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic_no_cat = Fabricate(:topic)

      post = Fabricate(:post, topic: topic, user: topic.user )
      _another_post = Fabricate(:post, topic: topic_no_cat, user: topic.user )

      search = Search.execute('hello', search_context: category)
      search.posts.length.should == 1
      search.posts.first.id.should == post.id
    end

  end

  describe 'Chinese search' do
    it 'splits English / Chinese' do
      SiteSetting.default_locale = 'zh_CN'
      data = Search.prepare_data('Discourse社区指南').split(' ')
      data.should == ['Discourse', '社区','指南']
    end

    it 'finds chinese topic based on title' do
      SiteSetting.default_locale = 'zh_TW'
      topic = Fabricate(:topic, title: 'My Title Discourse社区指南')
      post = Fabricate(:post, topic: topic)

      Search.execute('社区指南').posts.first.id.should == post.id
      Search.execute('指南').posts.first.id.should == post.id
    end
  end

  describe 'Advanced search' do
    it 'can find by status' do
      post = Fabricate(:post, raw: 'hi this is a test 123 123')
      topic = post.topic

      Search.execute('test status:closed').posts.length.should == 0
      Search.execute('test status:open').posts.length.should == 1

      topic.closed = true
      topic.save

      Search.execute('test status:closed').posts.length.should == 1
      Search.execute('test status:open').posts.length.should == 0

      topic.archived = true
      topic.closed = false
      topic.save

      Search.execute('test status:archived').posts.length.should == 1
      Search.execute('test status:open').posts.length.should == 0

      Search.execute('test status:noreplies').posts.length.should == 1

      Search.execute('test in:likes', guardian: Guardian.new(topic.user)).posts.length.should == 0

      Search.execute('test in:posted', guardian: Guardian.new(topic.user)).posts.length.should == 1

      TopicUser.change(topic.user.id, topic.id, notification_level: TopicUser.notification_levels[:tracking])
      Search.execute('test in:watching', guardian: Guardian.new(topic.user)).posts.length.should == 0
      Search.execute('test in:tracking', guardian: Guardian.new(topic.user)).posts.length.should == 1

    end

    it 'can find by latest' do
      topic1 = Fabricate(:topic, title: 'I do not like that Sam I am')
      post1 = Fabricate(:post, topic: topic1)

      post2 = Fabricate(:post, raw: 'that Sam I am, that Sam I am')

      Search.execute('sam').posts.map(&:id).should == [post1.id, post2.id]
      Search.execute('sam order:latest').posts.map(&:id).should == [post2.id, post1.id]

    end
  end

end

