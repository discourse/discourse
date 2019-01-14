# encoding: utf-8

require 'rails_helper'
require_dependency 'search'

describe Search do

  class TextHelper
    extend ActionView::Helpers::TextHelper
  end

  before do
    SearchIndexer.enable
  end

  context 'post indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @topic = Fabricate(:topic, title: 'sam saffron test topic', category: @category)
      @post = Fabricate(:post, topic: @topic, raw: 'this <b>fun test</b> <img src="bla" title="my image">')
      @indexed = @post.post_search_data.search_data
    end

    it "should index correctly" do
      expect(@indexed).to match(/fun/)
      expect(@indexed).to match(/sam/)
      expect(@indexed).to match(/america/)

      @topic.title = "harpi is the new title"
      @topic.save!
      @post.post_search_data.reload

      @indexed = @post.post_search_data.search_data

      expect(@indexed).to match(/harpi/)
    end
  end

  context 'user indexing observer' do
    before do
      @user = Fabricate(:user, username: 'fred', name: 'bob jones')
      @indexed = @user.user_search_data.search_data
    end

    it "should pick up on data" do
      expect(@indexed).to match(/fred/)
      expect(@indexed).to match(/jone/)
    end
  end

  context 'category indexing observer' do
    before do
      @category = Fabricate(:category, name: 'america')
      @indexed = @category.category_search_data.search_data
    end

    it "should pick up on name" do
      expect(@indexed).to match(/america/)
    end

  end

  it 'strips zero-width characters from search terms' do
    term = "\u0063\u0061\u0070\u0079\u200b\u200c\u200d\ufeff\u0062\u0061\u0072\u0061".encode("UTF-8")

    expect(term == 'capybara').to eq(false)

    search = Search.new(term)
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('capybara')
    expect(search.clean_term).to eq('capybara')
  end

  it 'replaces curly quotes to regular quotes in search terms' do
    term = '“discourse”'

    expect(term == '"discourse"').to eq(false)

    search = Search.new(term)
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('"discourse"')
    expect(search.clean_term).to eq('"discourse"')
  end

  it 'does not search when the search term is too small' do
    search = Search.new('evil', min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(false)
    expect(search.term).to eq('')
  end

  it 'needs at least one term that hits the length' do
    search = Search.new('a b c d', min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(false)
    expect(search.term).to eq('')
  end

  it 'searches for quoted short terms' do
    search = Search.new('"a b c d"', min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('"a b c d"')
  end

  it 'searches for short terms if one hits the length' do
    search = Search.new('a b c okaylength', min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('a b c okaylength')
  end

  it 'escapes non alphanumeric characters' do
    expect(Search.execute('foo :!$);}]>@\#\"\'').posts.length).to eq(0) # There are at least three levels of sanitation for Search.query!
  end

  it "doesn't raise an error when single quotes are present" do
    expect(Search.execute("'hello' world").posts.length).to eq(0) # There are at least three levels of sanitation for Search.query!
  end

  it 'works when given two terms with spaces' do
    expect { Search.execute('evil trout') }.not_to raise_error
  end

  context 'users' do
    let!(:user) { Fabricate(:user) }
    let(:result) { Search.execute('bruce', type_filter: 'user') }

    it 'returns a result' do
      expect(result.users.length).to eq(1)
      expect(result.users[0].id).to eq(user.id)
    end

    context 'hiding user profiles' do
      before { SiteSetting.hide_user_profiles_from_public = true }

      it 'returns no result for anon' do
        expect(result.users.length).to eq(0)
      end

      it 'returns a result for logged in users' do
        result = Search.execute('bruce', type_filter: 'user', guardian: Guardian.new(user))
        expect(result.users.length).to eq(1)
      end

    end

  end

  context 'inactive users' do
    let!(:inactive_user) { Fabricate(:inactive_user, active: false) }
    let(:result) { Search.execute('bruce') }

    it 'does not return a result' do
      expect(result.users.length).to eq(0)
    end
  end

  context 'staged users' do
    let(:staged) { Fabricate(:staged) }
    let(:result) { Search.execute(staged.username) }

    it 'does not return a result' do
      expect(result.users.length).to eq(0)
    end
  end

  context 'private messages' do

    let(:topic) {
      Fabricate(:topic,
                  category_id: nil,
                  archetype: 'private_message')
    }

    let(:post) { Fabricate(:post, topic: topic) }
    let(:reply) { Fabricate(:post, topic: topic,
                                   raw: 'hello from mars, we just landed') }

    it 'searches correctly' do

      expect do
        Search.execute('mars', type_filter: 'private_messages')
      end.to raise_error(Discourse::InvalidAccess)

      TopicAllowedUser.create!(user_id: reply.user_id, topic_id: topic.id)
      TopicAllowedUser.create!(user_id: post.user_id, topic_id: topic.id)

      results = Search.execute('mars',
                              type_filter: 'private_messages',
                              guardian: Guardian.new(reply.user))

      expect(results.posts.length).to eq(1)

      results = Search.execute('mars',
                              search_context: topic,
                              guardian: Guardian.new(reply.user))

      expect(results.posts.length).to eq(1)

      # does not leak out
      results = Search.execute('mars',
                              type_filter: 'private_messages',
                              guardian: Guardian.new(Fabricate(:user)))

      expect(results.posts.length).to eq(0)

      Fabricate(:topic, category_id: nil, archetype: 'private_message')
      Fabricate(:post, topic: topic, raw: 'another secret pm from mars, testing')

      # admin can search everything with correct context
      results = Search.execute('mars',
                              type_filter: 'private_messages',
                              search_context: post.user,
                              guardian: Guardian.new(Fabricate(:admin)))

      expect(results.posts.length).to eq(1)

      results = Search.execute('mars in:private',
                              search_context: post.user,
                              guardian: Guardian.new(post.user))

      expect(results.posts.length).to eq(1)

      # can search group PMs as well as non admin
      #
      user = Fabricate(:user)
      group = Fabricate.build(:group)
      group.add(user)
      group.save!

      TopicAllowedGroup.create!(group_id: group.id, topic_id: topic.id)

      results = Search.execute('mars in:private',
                              guardian: Guardian.new(user))

      expect(results.posts.length).to eq(1)

    end

  end

  context 'topics' do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    context 'search within topic' do

      def new_post(raw, topic = nil)
        topic ||= Fabricate(:topic)
        Fabricate(:post, topic: topic, topic_id: topic.id, user: topic.user, raw: raw)
      end

      it 'works in Chinese' do
        SiteSetting.search_tokenize_chinese_japanese_korean = true
        post = new_post('I am not in English 何点になると思いますか')

        results = Search.execute('何点になると思', search_context: post.topic)
        expect(results.posts.map(&:id)).to eq([post.id])
      end

      it 'displays multiple results within a topic' do
        topic = Fabricate(:topic)
        topic2 = Fabricate(:topic)

        new_post('this is the other post I am posting', topic2)
        new_post('this is my fifth post I am posting', topic2)

        post1 = new_post('this is the other post I am posting', topic)
        post2 = new_post('this is my first post I am posting', topic)
        post3 = new_post('this is a real long and complicated bla this is my second post I am Posting birds with more stuff bla bla', topic)
        post4 = new_post('this is my fourth post I am posting', topic)

        # update posts_count
        topic.reload

        results = Search.execute('posting', search_context: post1.topic)
        expect(results.posts.map(&:id)).to eq([post1.id, post2.id, post3.id, post4.id])

        results = Search.execute('posting l', search_context: post1.topic)
        expect(results.posts.map(&:id)).to eq([post4.id, post3.id, post2.id, post1.id])

        # stop words should work
        results = Search.execute('this', search_context: post1.topic)
        expect(results.posts.length).to eq(4)

        # phrase search works as expected
        results = Search.execute('"fourth post I am posting"', search_context: post1.topic)
        expect(results.posts.length).to eq(1)
      end

      it "works for unlisted topics" do
        topic.update_attributes(visible: false)
        _post = new_post('discourse is awesome', topic)
        results = Search.execute('discourse', search_context: topic)
        expect(results.posts.length).to eq(1)
      end
    end

    context 'searching the OP' do
      let!(:post) { Fabricate(:post_with_long_raw_content) }
      let(:result) { Search.execute('hundred', type_filter: 'topic', include_blurbs: true) }

      it 'returns a result correctly' do
        expect(result.posts.length).to eq(1)
        expect(result.posts[0].id).to eq(post.id)
      end
    end

    context 'searching for a post' do
      let!(:reply) { Fabricate(:basic_reply, topic: topic, user: topic.user) }
      let(:result) { Search.execute('quotes', type_filter: 'topic', include_blurbs: true) }

      it 'returns the post' do
        expect(result).to be_present
        expect(result.posts.length).to eq(1)
        p = result.posts[0]
        expect(p.topic.id).to eq(topic.id)
        expect(p.id).to eq(reply.id)
        expect(result.blurb(p)).to eq("this reply has no quotes")
      end
    end

    context 'searching for quoted title' do
      it "can find quoted title" do
        create_post(raw: "this is the raw body", title: "I am a title yeah")
        result = Search.execute('"a title yeah"')

        expect(result.posts.length).to eq(1)
      end

    end

    context "search for a topic by id" do
      let(:result) { Search.execute(topic.id, type_filter: 'topic', search_for_id: true, min_search_term_length: 1) }

      it 'returns the topic' do
        expect(result.posts.length).to eq(1)
        expect(result.posts.first.id).to eq(post.id)
      end
    end

    context "search for a topic by url" do
      it 'returns the topic' do
        result = Search.execute(topic.relative_url, search_for_id: true, type_filter: 'topic')
        expect(result.posts.length).to eq(1)
        expect(result.posts.first.id).to eq(post.id)
      end

      context 'restrict_to_archetype' do
        let(:personal_message) { Fabricate(:private_message_topic) }
        let!(:p1) { Fabricate(:post, topic: personal_message, post_number: 1) }

        it 'restricts result to topics' do
          result = Search.execute(personal_message.relative_url, search_for_id: true, type_filter: 'topic', restrict_to_archetype: Archetype.default)
          expect(result.posts.length).to eq(0)

          result = Search.execute(topic.relative_url, search_for_id: true, type_filter: 'topic', restrict_to_archetype: Archetype.default)
          expect(result.posts.length).to eq(1)
        end

        it 'restricts result to messages' do
          result = Search.execute(topic.relative_url, search_for_id: true, type_filter: 'private_messages', guardian: Guardian.new(Fabricate(:admin)), restrict_to_archetype: Archetype.private_message)
          expect(result.posts.length).to eq(0)

          result = Search.execute(personal_message.relative_url, search_for_id: true, type_filter: 'private_messages', guardian: Guardian.new(Fabricate(:admin)), restrict_to_archetype: Archetype.private_message)
          expect(result.posts.length).to eq(1)
        end
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

        category.set_permissions(staff: :full)
        category.save

        expect(result(nil).posts).not_to be_present
        expect(result(Fabricate(:user)).posts).not_to be_present
        expect(result(Fabricate(:admin)).posts).to be_present

      end
    end

  end

  context 'cyrillic topic' do
    let!(:cyrillic_topic) { Fabricate(:topic) do
                              user
                                                title { sequence(:title) { |i| "Тестовая запись #{i}" } }
                            end
    }
    let!(:post) { Fabricate(:post, topic: cyrillic_topic, user: cyrillic_topic.user) }
    let(:result) { Search.execute('запись') }

    it 'finds something when given cyrillic query' do
      expect(result.posts).to be_present
    end
  end

  it 'does not tokenize search term' do
    Fabricate(:post, raw: 'thing is canned should still be found!')
    expect(Search.execute('canned').posts).to be_present
  end

  context 'categories' do

    let!(:category) { Fabricate(:category) }
    def search
      Search.execute(category.name)
    end

    it 'returns the correct result' do
      expect(search.categories).to be_present

      category.set_permissions({})
      category.save

      expect(search.categories).not_to be_present
    end

  end

  context 'tags' do
    def search
      Search.execute(tag.name)
    end

    let!(:tag) { Fabricate(:tag) }
    let!(:uppercase_tag) { Fabricate(:tag, name: "HeLlO") }
    let(:tag_group) { Fabricate(:tag_group) }
    let(:category) { Fabricate(:category) }

    context 'post searching' do
      it 'can find posts with tags' do
        SiteSetting.tagging_enabled = true

        post = Fabricate(:post, raw: 'I am special post')
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(Fabricate.build(:admin)), [tag.name, uppercase_tag.name])
        post.topic.save

        # we got to make this index (it is deferred)
        Jobs::ReindexSearch.new.rebuild_problem_posts

        result = Search.execute(tag.name)
        expect(result.posts.length).to eq(1)

        result = Search.execute("hElLo")
        expect(result.posts.length).to eq(1)

        SiteSetting.tagging_enabled = false

        result = Search.execute(tag.name)
        expect(result.posts.length).to eq(0)
      end
    end

    context 'tagging is disabled' do
      before { SiteSetting.tagging_enabled = false }

      it 'does not include tags' do
        expect(search.tags).to_not be_present
      end
    end

    context 'tagging is enabled' do
      before { SiteSetting.tagging_enabled = true }

      it 'returns the tag in the result' do
        expect(search.tags).to eq([tag])
      end

      it 'shows staff tags' do
        create_staff_tags(["#{tag.name}9"])

        expect(Search.execute(tag.name, guardian: Guardian.new(Fabricate(:admin))).tags.map(&:name)).to contain_exactly(tag.name, "#{tag.name}9")
        expect(search.tags.map(&:name)).to contain_exactly(tag.name, "#{tag.name}9")
      end

      it 'includes category-restricted tags' do
        category_tag = Fabricate(:tag, name: "#{tag.name}9")
        tag_group.tags = [category_tag]
        category.set_permissions(admins: :full)
        category.allowed_tag_groups = [tag_group.name]
        category.save!

        expect(Search.execute(tag.name, guardian: Guardian.new(Fabricate(:admin))).tags).to contain_exactly(tag, category_tag)
        expect(search.tags).to contain_exactly(tag, category_tag)
      end
    end
  end

  context 'type_filter' do

    let!(:user) { Fabricate(:user, username: 'amazing', email: 'amazing@amazing.com') }
    let!(:category) { Fabricate(:category, name: 'amazing category', user: user) }

    context 'user filter' do
      let(:results) { Search.execute('amazing', type_filter: 'user') }

      it "returns a user result" do
        expect(results.categories.length).to eq(0)
        expect(results.posts.length).to eq(0)
        expect(results.users.length).to eq(1)
      end

    end

    context 'category filter' do
      let(:results) { Search.execute('amazing', type_filter: 'category') }

      it "returns a category result" do
        expect(results.categories.length).to eq(1)
        expect(results.posts.length).to eq(0)
        expect(results.users.length).to eq(0)
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
      expect(result.posts.length).to eq(1)
    end

    it 'can use category as a search context' do
      category = Fabricate(:category)
      topic = Fabricate(:topic, category: category)
      topic_no_cat = Fabricate(:topic)

      # includes subcategory in search
      subcategory = Fabricate(:category, parent_category_id: category.id)
      sub_topic = Fabricate(:topic, category: subcategory)

      post = Fabricate(:post, topic: topic, user: topic.user)
      _another_post = Fabricate(:post, topic: topic_no_cat, user: topic.user)
      sub_post = Fabricate(:post, raw: 'I am saying hello from a subcategory', topic: sub_topic, user: topic.user)

      search = Search.execute('hello', search_context: category)
      expect(search.posts.map(&:id).sort).to eq([post.id, sub_post.id].sort)
      expect(search.posts.length).to eq(2)
    end

  end

  describe 'Chinese search' do
    let(:sentence) { 'Discourse中国的基础设施网络正在组装' }
    let(:sentence_t) { 'Discourse太平山森林遊樂區' }

    it 'splits English / Chinese and filter out stop words' do
      SiteSetting.default_locale = 'zh_CN'
      data = Search.prepare_data(sentence).split(' ')
      expect(data).to eq(["Discourse", "中国", "基础", "设施", "基础设施", "网络", "正在", "组装"])
    end

    it 'splits for indexing and filter out stop words' do
      SiteSetting.default_locale = 'zh_CN'
      data = Search.prepare_data(sentence, :index).split(' ')
      expect(data).to eq(["Discourse", "中国", "基础设施", "网络", "正在", "组装"])
    end

    it 'splits English / Traditional Chinese and filter out stop words' do
      SiteSetting.default_locale = 'zh_TW'
      data = Search.prepare_data(sentence_t).split(' ')
      expect(data).to eq(["Discourse", "太平", "平山", "太平山", "森林", "遊樂區"])
    end

    it 'splits for indexing and filter out stop words' do
      SiteSetting.default_locale = 'zh_TW'
      data = Search.prepare_data(sentence_t, :index).split(' ')
      expect(data).to eq(["Discourse", "太平山", "森林", "遊樂區"])
    end

    it 'finds chinese topic based on title' do
      skip("skipped until pg app installs the db correctly") if RbConfig::CONFIG["arch"] =~ /darwin/

      SiteSetting.default_locale = 'zh_TW'
      SiteSetting.min_search_term_length = 1
      topic = Fabricate(:topic, title: 'My Title Discourse社區指南')
      post = Fabricate(:post, topic: topic)

      expect(Search.execute('社區指南').posts.first.id).to eq(post.id)
      expect(Search.execute('指南').posts.first.id).to eq(post.id)
    end

    it 'finds chinese topic based on title if tokenization is forced' do
      skip("skipped until pg app installs the db correctly") if RbConfig::CONFIG["arch"] =~ /darwin/

      SiteSetting.search_tokenize_chinese_japanese_korean = true
      SiteSetting.min_search_term_length = 1

      topic = Fabricate(:topic, title: 'My Title Discourse社區指南')
      post = Fabricate(:post, topic: topic)

      expect(Search.execute('社區指南').posts.first.id).to eq(post.id)
      expect(Search.execute('指南').posts.first.id).to eq(post.id)
    end
  end

  describe 'Advanced search' do

    it 'supports pinned and unpinned' do
      topic = Fabricate(:topic)
      Fabricate(:post, raw: 'hi this is a test 123 123', topic: topic)
      _post = Fabricate(:post, raw: 'boom boom shake the room', topic: topic)

      topic.update_pinned(true)

      user = Fabricate(:user)
      guardian = Guardian.new(user)

      expect(Search.execute('boom in:pinned').posts.length).to eq(1)
      expect(Search.execute('boom in:unpinned', guardian: guardian).posts.length).to eq(0)

      topic.clear_pin_for(user)

      expect(Search.execute('boom in:unpinned', guardian: guardian).posts.length).to eq(1)
    end

    it 'supports wiki' do
      topic = Fabricate(:topic)
      topic_2 = Fabricate(:topic)
      post = Fabricate(:post, raw: 'this is a test 248', wiki: true, topic: topic)
      Fabricate(:post, raw: 'this is a test 248', wiki: false, topic: topic_2)

      expect(Search.execute('test 248').posts.length).to eq(2)
      expect(Search.execute('test 248 in:wiki').posts.first).to eq(post)
    end

    it 'supports searching for posts that the user has seen/unseen' do
      topic = Fabricate(:topic)
      topic_2 = Fabricate(:topic)
      post = Fabricate(:post, raw: 'logan is longan', topic: topic)
      post_2 = Fabricate(:post, raw: 'longan is logan', topic: topic_2)

      [post.user, topic.user].each do |user|
        PostTiming.create!(
          post_number: post.post_number,
          topic: topic,
          user: user,
          msecs: 1
        )
      end

      expect(post.seen?(post.user)).to eq(true)

      expect(Search.execute('longan').posts.sort).to eq([post, post_2])

      expect(Search.execute('longan in:seen', guardian: Guardian.new(post.user)).posts)
        .to eq([post])

      expect(Search.execute('longan in:seen').posts.sort).to eq([post, post_2])

      expect(Search.execute('longan in:seen', guardian: Guardian.new(post_2.user)).posts)
        .to eq([])

      expect(Search.execute('longan', guardian: Guardian.new(post_2.user)).posts.sort)
        .to eq([post, post_2])

      expect(Search.execute('longan in:unseen', guardian: Guardian.new(post_2.user)).posts.sort)
        .to eq([post, post_2])

      expect(Search.execute('longan in:unseen', guardian: Guardian.new(post.user)).posts)
        .to eq([post_2])
    end

    it 'supports before and after, in:first, user:, @username' do

      time = Time.zone.parse('2001-05-20 2:55')
      freeze_time(time)

      topic = Fabricate(:topic)
      Fabricate(:post, raw: 'hi this is a test 123 123', topic: topic, created_at: time.months_ago(2))
      _post = Fabricate(:post, raw: 'boom boom shake the room', topic: topic)

      expect(Search.execute('test before:1').posts.length).to eq(1)
      expect(Search.execute('test before:2001-04-20').posts.length).to eq(1)
      expect(Search.execute('test before:2001').posts.length).to eq(0)
      expect(Search.execute('test before:monday').posts.length).to eq(1)

      expect(Search.execute('test after:jan').posts.length).to eq(1)

      expect(Search.execute('test in:first').posts.length).to eq(1)
      expect(Search.execute('boom').posts.length).to eq(1)
      expect(Search.execute('boom in:first').posts.length).to eq(0)

      expect(Search.execute('user:nobody').posts.length).to eq(0)
      expect(Search.execute("user:#{_post.user.username}").posts.length).to eq(1)
      expect(Search.execute("user:#{_post.user_id}").posts.length).to eq(1)

      expect(Search.execute("@#{_post.user.username}").posts.length).to eq(1)
    end

    it 'supports group' do
      topic = Fabricate(:topic, created_at: 3.months.ago)
      post = Fabricate(:post, raw: 'hi this is a test 123 123', topic: topic)

      group = Group.create!(name: "Like_a_Boss")
      GroupUser.create!(user_id: post.user_id, group_id: group.id)

      expect(Search.execute('group:like_a_boss').posts.length).to eq(1)
      expect(Search.execute('group:"like a brick"').posts.length).to eq(0)
    end

    it 'supports badge' do

      topic = Fabricate(:topic, created_at: 3.months.ago)
      post = Fabricate(:post, raw: 'hi this is a test 123 123', topic: topic)

      badge = Badge.create!(name: "Like a Boss", badge_type_id: 1)
      UserBadge.create!(user_id: post.user_id, badge_id: badge.id, granted_at: 1.minute.ago, granted_by_id: -1)

      expect(Search.execute('badge:"like a boss"').posts.length).to eq(1)
      expect(Search.execute('badge:"test"').posts.length).to eq(0)
    end

    it 'can search numbers correctly, and match exact phrases' do
      topic = Fabricate(:topic, created_at: 3.months.ago)
      Fabricate(:post, raw: '3.0 eta is in 2 days horrah', topic: topic)

      expect(Search.execute('3.0 eta').posts.length).to eq(1)
      expect(Search.execute('"3.0, eta is"').posts.length).to eq(0)
    end

    it 'can find by status' do
      post = Fabricate(:post, raw: 'hi this is a test 123 123')
      topic = post.topic

      expect(Search.execute('test status:closed').posts.length).to eq(0)
      expect(Search.execute('test status:open').posts.length).to eq(1)
      expect(Search.execute('test posts_count:1').posts.length).to eq(1)
      expect(Search.execute('test min_post_count:1').posts.length).to eq(1)

      topic.closed = true
      topic.save

      expect(Search.execute('test status:closed').posts.length).to eq(1)
      expect(Search.execute('status:closed').posts.length).to eq(1)
      expect(Search.execute('test status:open').posts.length).to eq(0)

      topic.archived = true
      topic.closed = false
      topic.save

      expect(Search.execute('test status:archived').posts.length).to eq(1)
      expect(Search.execute('test status:open').posts.length).to eq(0)

      expect(Search.execute('test status:noreplies').posts.length).to eq(1)

      expect(Search.execute('test in:likes', guardian: Guardian.new(topic.user)).posts.length).to eq(0)

      expect(Search.execute('test in:posted', guardian: Guardian.new(topic.user)).posts.length).to eq(1)

      TopicUser.change(topic.user.id, topic.id, notification_level: TopicUser.notification_levels[:tracking])
      expect(Search.execute('test in:watching', guardian: Guardian.new(topic.user)).posts.length).to eq(0)
      expect(Search.execute('test in:tracking', guardian: Guardian.new(topic.user)).posts.length).to eq(1)

    end

    it 'can find posts with images' do
      post_uploaded = Fabricate(:post_with_uploaded_image)
      post_with_image_urls = Fabricate(:post_with_image_urls)
      Fabricate(:post)

      CookedPostProcessor.new(post_uploaded).update_post_image
      CookedPostProcessor.new(post_with_image_urls).update_post_image

      expect(Search.execute('with:images').posts.map(&:id)).to contain_exactly(post_uploaded.id, post_with_image_urls.id)
    end

    it 'can find by latest' do
      topic1 = Fabricate(:topic, title: 'I do not like that Sam I am')
      post1 = Fabricate(:post, topic: topic1)

      post2 = Fabricate(:post, raw: 'that Sam I am, that Sam I am')

      expect(Search.execute('sam').posts.map(&:id)).to eq([post1.id, post2.id])
      expect(Search.execute('sam order:latest').posts.map(&:id)).to eq([post2.id, post1.id])
      expect(Search.execute('sam l').posts.map(&:id)).to eq([post2.id, post1.id])
      expect(Search.execute('l sam').posts.map(&:id)).to eq([post2.id, post1.id])
    end

    it 'can order by topic creation' do
      today        = Date.today
      yesterday    = 1.day.ago
      two_days_ago = 2.days.ago

      old_topic    = Fabricate(:topic,
          title: 'First Topic, testing the created_at sort',
          created_at: two_days_ago)
      latest_topic = Fabricate(:topic,
          title: 'Second Topic, testing the created_at sort',
          created_at: yesterday)

      old_relevant_topic_post     = Fabricate(:post, topic: old_topic, created_at: yesterday, raw: 'Relevant Topic')
      latest_irelevant_topic_post = Fabricate(:post, topic: latest_topic, created_at: today, raw: 'Not Relevant')

      # Expecting the default results
      expect(Search.execute('Topic').posts.map(&:id)).to eq([old_relevant_topic_post.id, latest_irelevant_topic_post.id])

      # Expecting the ordered by topic creation results
      expect(Search.execute('Topic order:latest_topic').posts.map(&:id)).to eq([latest_irelevant_topic_post.id, old_relevant_topic_post.id])
    end

    it 'can tokenize dots' do
      post = Fabricate(:post, raw: 'Will.2000 Will.Bob.Bill...')
      expect(Search.execute('bill').posts.map(&:id)).to eq([post.id])
    end

    it 'can tokanize website names correctly' do
      post = Fabricate(:post, raw: 'i like http://wb.camra.org.uk/latest#test so yay')
      expect(Search.execute('http://wb.camra.org.uk/latest#test').posts.map(&:id)).to eq([post.id])
      expect(Search.execute('camra').posts.map(&:id)).to eq([post.id])
    end

    it 'supports category slug and tags' do
      # main category
      category = Fabricate(:category, name: 'category 24', slug: 'category-24')
      topic = Fabricate(:topic, created_at: 3.months.ago, category: category)
      post = Fabricate(:post, raw: 'Sams first post', topic: topic)

      expect(Search.execute('sams post #category-24').posts.length).to eq(1)
      expect(Search.execute("sams post category:#{category.id}").posts.length).to eq(1)
      expect(Search.execute('sams post #category-25').posts.length).to eq(0)

      sub_category = Fabricate(:category, name: 'sub category', slug: 'sub-category', parent_category_id: category.id)
      second_topic = Fabricate(:topic, created_at: 3.months.ago, category: sub_category)
      Fabricate(:post, raw: 'sams second post', topic: second_topic)

      expect(Search.execute("sams post category:category-24").posts.length).to eq(2)
      expect(Search.execute("sams post category:=category-24").posts.length).to eq(1)

      expect(Search.execute("sams post #category-24").posts.length).to eq(2)
      expect(Search.execute("sams post #=category-24").posts.length).to eq(1)
      expect(Search.execute("sams post #sub-category").posts.length).to eq(1)

      # tags
      topic.tags = [Fabricate(:tag, name: 'alpha'), Fabricate(:tag, name: 'привет'), Fabricate(:tag, name: 'HeLlO')]
      expect(Search.execute('this is a test #alpha').posts.map(&:id)).to eq([post.id])
      expect(Search.execute('this is a test #привет').posts.map(&:id)).to eq([post.id])
      expect(Search.execute('this is a test #hElLo').posts.map(&:id)).to eq([post.id])
      expect(Search.execute('this is a test #beta').posts.size).to eq(0)
    end

    it 'correctly handles #symbol when no tag or category match' do
      Fabricate(:post, raw: 'testing #1 #9998')
      results = Search.new('testing #1').execute
      expect(results.posts.length).to eq(1)

      results = Search.new('#9998').execute
      expect(results.posts.length).to eq(1)

      results = Search.new('#777').execute
      expect(results.posts.length).to eq(0)

      results = Search.new('xxx #:').execute
      expect(results.posts.length).to eq(0)
    end

    context 'tags' do
      let(:tag1) { Fabricate(:tag, name: 'lunch') }
      let(:tag2) { Fabricate(:tag, name: 'eggs') }
      let(:tag3) { Fabricate(:tag, name: 'sandwiches') }
      let(:topic1) { Fabricate(:topic, tags: [tag2, Fabricate(:tag)]) }
      let(:topic2) { Fabricate(:topic, tags: [tag2]) }
      let(:topic3) { Fabricate(:topic, tags: [tag1, tag2]) }
      let(:topic4) { Fabricate(:topic, tags: [tag1, tag2, tag3]) }
      let(:topic5) { Fabricate(:topic, tags: [tag2, tag3]) }
      let!(:post1) { Fabricate(:post, topic: topic1) }
      let!(:post2) { Fabricate(:post, topic: topic2) }
      let!(:post3) { Fabricate(:post, topic: topic3) }
      let!(:post4) { Fabricate(:post, topic: topic4) }
      let!(:post5) { Fabricate(:post, topic: topic5) }

      it 'can find posts with tag' do
        post4 = Fabricate(:post, topic: topic3, raw: "It probably doesn't help that they're green...")

        expect(Search.execute('green tags:eggs').posts.map(&:id)).to eq([post4.id])
        expect(Search.execute('tags:plants').posts.size).to eq(0)
      end

      it 'can find posts with non-latin tag' do
        topic = Fabricate(:topic)
        topic.tags = [Fabricate(:tag, name: 'さようなら')]
        post = Fabricate(:post, raw: 'Testing post', topic: topic)

        expect(Search.execute('tags:さようなら').posts.map(&:id)).to eq([post.id])
      end

      it 'can find posts with any tag from multiple tags' do
        Fabricate(:post)

        expect(Search.execute('tags:eggs,lunch').posts.map(&:id).sort).to eq([post1.id, post2.id, post3.id, post4.id, post5.id].sort)
      end

      it 'can find posts which contains all provided tags' do
        expect(Search.execute('tags:lunch+eggs+sandwiches').posts.map(&:id)).to eq([post4.id].sort)
        expect(Search.execute('tags:eggs+lunch+sandwiches').posts.map(&:id)).to eq([post4.id].sort)
      end

      it 'can find posts which contains provided tags and does not contain selected ones' do
        expect(Search.execute('tags:eggs -tags:lunch').posts)
          .to contain_exactly(post1, post2, post5)

        expect(Search.execute('tags:eggs -tags:lunch+sandwiches').posts)
          .to contain_exactly(post1, post2, post3, post5)

        expect(Search.execute('tags:eggs -tags:lunch,sandwiches').posts)
          .to contain_exactly(post1, post2)
      end

      it 'orders posts correctly when combining tags with categories or terms' do
        cat1 = Fabricate(:category, name: 'food')
        topic6 = Fabricate(:topic, tags: [tag1, tag2], category: cat1)
        topic7 = Fabricate(:topic, tags: [tag1, tag2, tag3], category: cat1)
        post7 = Fabricate(:post, topic: topic6, raw: "Wakey, wakey, eggs and bakey.", like_count: 5)
        post8 = Fabricate(:post, topic: topic7, raw: "Bakey, bakey, eggs to makey.", like_count: 2)

        expect(Search.execute('bakey tags:lunch order:latest').posts.map(&:id))
          .to eq([post8.id, post7.id])
        expect(Search.execute('#food tags:lunch order:latest').posts.map(&:id))
          .to eq([post8.id, post7.id])
        expect(Search.execute('#food tags:lunch order:likes').posts.map(&:id))
          .to eq([post7.id, post8.id])
      end

    end

    it "can find posts which contains filetypes" do
      post1 = Fabricate(:post,
                        raw: "http://example.com/image.png")
      post2 = Fabricate(:post,
                         raw: "Discourse logo\n"\
                              "http://example.com/logo.png\n"\
                              "http://example.com/vector_image.svg")
      post_with_upload = Fabricate(:post, uploads: [Fabricate(:upload)])
      Fabricate(:post)

      TopicLink.extract_from(post1)
      TopicLink.extract_from(post2)

      expect(Search.execute('filetype:svg').posts).to eq([post2])
      expect(Search.execute('filetype:png').posts.map(&:id)).to contain_exactly(post1.id, post2.id, post_with_upload.id)
      expect(Search.execute('logo filetype:png').posts.map(&:id)).to eq([post2.id])
    end
  end

  context '#ts_query' do
    it 'can parse complex strings using ts_query helper' do
      str = " grigio:babel deprecated? "
      str << "page page on Atmosphere](https://atmospherejs.com/grigio/babel)xxx: aaa.js:222 aaa'\"bbb"

      ts_query = Search.ts_query(term: str, ts_config: "simple")
      expect { DB.exec("SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error

      ts_query = Search.ts_query(term: "foo.bar/'&baz", ts_config: "simple")
      expect { DB.exec("SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error
      expect(ts_query).to include("baz")
    end
  end

  context '#word_to_date' do
    it 'parses relative dates correctly' do
      time = Time.zone.parse('2001-02-20 2:55')
      freeze_time(time)

      expect(Search.word_to_date('yesterday')).to eq(time.beginning_of_day.yesterday)
      expect(Search.word_to_date('suNday')).to eq(Time.zone.parse('2001-02-18'))
      expect(Search.word_to_date('thursday')).to eq(Time.zone.parse('2001-02-15'))
      expect(Search.word_to_date('deCember')).to eq(Time.zone.parse('2000-12-01'))
      expect(Search.word_to_date('deC')).to eq(Time.zone.parse('2000-12-01'))
      expect(Search.word_to_date('january')).to eq(Time.zone.parse('2001-01-01'))
      expect(Search.word_to_date('jan')).to eq(Time.zone.parse('2001-01-01'))

      expect(Search.word_to_date('100')).to eq(time.beginning_of_day.days_ago(100))

      expect(Search.word_to_date('invalid')).to eq(nil)
    end

    it 'parses absolute dates correctly' do
      expect(Search.word_to_date('2001-1-20')).to eq(Time.zone.parse('2001-01-20'))
      expect(Search.word_to_date('2030-10-2')).to eq(Time.zone.parse('2030-10-02'))
      expect(Search.word_to_date('2030-10')).to eq(Time.zone.parse('2030-10-01'))
      expect(Search.word_to_date('2030')).to eq(Time.zone.parse('2030-01-01'))
      expect(Search.word_to_date('2030-01-32')).to eq(nil)
      expect(Search.word_to_date('10000')).to eq(nil)
    end
  end

  context "#min_post_id" do
    it "returns 0 when prefer_recent_posts is disabled" do
      SiteSetting.search_prefer_recent_posts = false
      expect(Search.min_post_id_no_cache).to eq(0)
    end

    it "returns a value when prefer_recent_posts is enabled" do
      SiteSetting.search_prefer_recent_posts = true
      SiteSetting.search_recent_posts_size = 1

      Fabricate(:post)
      p2 = Fabricate(:post)

      expect(Search.min_post_id_no_cache).to eq(p2.id)
    end
  end

  context "search_log_id" do
    it "returns an id when the search succeeds" do
      s = Search.new(
        'indiana jones',
        search_type: :header,
        ip_address: '127.0.0.1'
      )
      results = s.execute
      expect(results.search_log_id).to be_present
    end

    it "does not log search if search_type is not present" do
      s = Search.new('foo bar', ip_address: '127.0.0.1')
      results = s.execute
      expect(results.search_log_id).not_to be_present
    end
  end

  context 'in:title' do
    it 'allows for search in title' do
      topic = Fabricate(:topic, title: 'I am testing a title search')
      _post = Fabricate(:post, topic: topic, raw: 'this is the first post')

      results = Search.execute('title in:title')
      expect(results.posts.length).to eq(1)

      results = Search.execute('first in:title')
      expect(results.posts.length).to eq(0)
    end
  end

  context 'ignore_diacritics' do
    before { SiteSetting.search_ignore_accents = true }
    let!(:post1) { Fabricate(:post, raw: 'สวัสดี Rágis hello') }

    it ('allows strips correctly') do
      results = Search.execute('hello', type_filter: 'topic')
      expect(results.posts.length).to eq(1)

      results = Search.execute('ragis', type_filter: 'topic')
      expect(results.posts.length).to eq(1)

      results = Search.execute('Rágis', type_filter: 'topic', include_blurbs: true)
      expect(results.posts.length).to eq(1)

      # TODO: this is a test we need to fix!
      #expect(results.blurb(results.posts.first)).to include('Rágis')

      results = Search.execute('สวัสดี', type_filter: 'topic')
      expect(results.posts.length).to eq(1)
    end
  end

  context 'include_diacritics' do
    before { SiteSetting.search_ignore_accents = false }
    let!(:post1) { Fabricate(:post, raw: 'สวัสดี Régis hello') }

    it ('allows strips correctly') do
      results = Search.execute('hello', type_filter: 'topic')
      expect(results.posts.length).to eq(1)

      results = Search.execute('regis', type_filter: 'topic')
      expect(results.posts.length).to eq(0)

      results = Search.execute('Régis', type_filter: 'topic', include_blurbs: true)
      expect(results.posts.length).to eq(1)

      expect(results.blurb(results.posts.first)).to include('Régis')

      results = Search.execute('สวัสดี', type_filter: 'topic')
      expect(results.posts.length).to eq(1)
    end
  end

  context 'pagination' do
    let(:number_of_results) { 2 }
    let!(:post1) { Fabricate(:post, raw: 'hello hello hello hello hello') }
    let!(:post2) { Fabricate(:post, raw: 'hello hello hello hello') }
    let!(:post3) { Fabricate(:post, raw: 'hello hello hello') }
    let!(:post4) { Fabricate(:post, raw: 'hello hello') }
    let!(:post5) { Fabricate(:post, raw: 'hello') }
    before do
      Search.stubs(:per_filter).returns(number_of_results)
    end

    it 'returns more results flag' do
      results = Search.execute('hello', type_filter: 'topic')
      results2 = Search.execute('hello', type_filter: 'topic', page: 2)

      expect(results.posts.length).to eq(number_of_results)
      expect(results.posts.map(&:id)).to eq([post1.id, post2.id])
      expect(results.more_full_page_results).to eq(true)
      expect(results2.posts.length).to eq(number_of_results)
      expect(results2.posts.map(&:id)).to eq([post3.id, post4.id])
      expect(results2.more_full_page_results).to eq(true)
    end

    it 'correctly search with page parameter' do
      search = Search.new('hello', type_filter: 'topic', page: 3)
      results = search.execute

      expect(search.offset).to eq(2 * number_of_results)
      expect(results.posts.length).to eq(1)
      expect(results.posts).to eq([post5])
      expect(results.more_full_page_results).to eq(nil)
    end

  end

end
