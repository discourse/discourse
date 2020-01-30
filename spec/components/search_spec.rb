# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe Search do
  fab!(:admin) { Fabricate(:admin) }

  before do
    SearchIndexer.enable
  end

  context 'post indexing observer' do
    before do
      @category = Fabricate(:category_with_definition, name: 'america')
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
      @category = Fabricate(:category_with_definition, name: 'america')
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
                              guardian: Guardian.new(admin))

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

    context 'personal-direct flag' do
      let(:current) { Fabricate(:user, admin: true, username: "current_user") }
      let(:participant) { Fabricate(:user, username: "participant_1") }
      let(:participant_2) { Fabricate(:user, username: "participant_2") }

      let(:group) do
        group = Fabricate(:group, has_messages: true)
        group.add(current)
        group.add(participant)
        group
      end

      def create_pm(users:, group: nil)
        pm = Fabricate(:private_message_post_one_user, user: users.first).topic
        users[1..-1].each do |u|
          pm.invite(users.first, u.username)
          Fabricate(:post, user: u, topic: pm)
        end
        if group
          pm.invite_group(users.first, group)
          group.users.each do |u|
            Fabricate(:post, user: u, topic: pm)
          end
        end
        pm.reload
      end

      it 'can find all direct PMs of the current user' do
        pm = create_pm(users: [current, participant])
        pm_2 = create_pm(users: [participant_2, participant])
        pm_3 = create_pm(users: [participant, current])
        pm_4 = create_pm(users: [participant_2, current])
        results = Search.execute("in:personal-direct", guardian: Guardian.new(current))
        expect(results.posts.size).to eq(3)
        expect(results.posts.map(&:topic_id)).to contain_exactly(pm.id, pm_3.id, pm_4.id)
      end

      it 'can filter direct PMs by @username' do
        pm = create_pm(users: [current, participant])
        pm_2 = create_pm(users: [participant, current])
        pm_3 = create_pm(users: [participant_2, current])
        results = Search.execute("@#{participant.username} in:personal-direct", guardian: Guardian.new(current))
        expect(results.posts.size).to eq(2)
        expect(results.posts.map(&:topic_id)).to contain_exactly(pm.id, pm_2.id)
        expect(results.posts.map(&:user_id).uniq).to contain_exactly(participant.id)
      end

      it "doesn't include PMs that have more than 2 participants" do
        pm = create_pm(users: [current, participant, participant_2])
        results = Search.execute("@#{participant.username} in:personal-direct", guardian: Guardian.new(current))
        expect(results.posts.size).to eq(0)
      end

      it "doesn't include PMs that have groups" do
        pm = create_pm(users: [current, participant], group: group)
        results = Search.execute("@#{participant.username} in:personal-direct", guardian: Guardian.new(current))
        expect(results.posts.size).to eq(0)
      end
    end

    context 'all topics' do

      let!(:u1) { Fabricate(:user, username: 'fred', name: 'bob jones', email: 'foo+1@bar.baz') }
      let!(:u2) { Fabricate(:user, username: 'bob', name: 'fred jones', email: 'foo+2@bar.baz') }
      let!(:u3) { Fabricate(:user, username: 'jones', name: 'bob fred', email: 'foo+3@bar.baz') }
      let!(:u4) { Fabricate(:user, username: 'alice', name: 'bob fred', email: 'foo+4@bar.baz', admin: true) }

      let!(:public_topic) { Fabricate(:topic, user: u1) }
      let!(:public_post1) { Fabricate(:post, topic: public_topic, raw: "what do you want for breakfast?  ham and eggs?", user: u1) }
      let!(:public_post2) { Fabricate(:post, topic: public_topic, raw: "ham and spam", user: u2) }

      let!(:private_topic) { Fabricate(:topic, user: u1, category_id: nil, archetype: 'private_message') }
      let!(:private_post1) { Fabricate(:post, topic: private_topic, raw: "what do you want for lunch?  ham and cheese?", user: u1) }
      let!(:private_post2) { Fabricate(:post, topic: private_topic, raw: "cheese and spam", user: u2) }

      it 'finds private messages' do
        TopicAllowedUser.create!(user_id: u1.id, topic_id: private_topic.id)
        TopicAllowedUser.create!(user_id: u2.id, topic_id: private_topic.id)

        # private only
        results = Search.execute('cheese',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u1))
        expect(results.posts.length).to eq(1)

        # public only
        results = Search.execute('eggs',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u1))
        expect(results.posts.length).to eq(1)

        # both
        results = Search.execute('spam',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u1))
        expect(results.posts.length).to eq(2)

        # nonparticipatory user
        results = Search.execute('cheese',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u3))
        expect(results.posts.length).to eq(0)

        results = Search.execute('eggs',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u3))
        expect(results.posts.length).to eq(1)

        results = Search.execute('spam',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u3))
        expect(results.posts.length).to eq(1)

        # Admin doesn't see private topic
        results = Search.execute('spam',
                  type_filter: 'all_topics',
                  guardian: Guardian.new(u4))
        expect(results.posts.length).to eq(1)

        # same keyword for different users
        results = Search.execute('ham',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u1))
        expect(results.posts.length).to eq(2)
        results = Search.execute('ham',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u2))
        expect(results.posts.length).to eq(2)
        results = Search.execute('ham',
                                type_filter: 'all_topics',
                                guardian: Guardian.new(u3))
        expect(results.posts.length).to eq(1)
      end
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
        topic.update(visible: false)
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
      let!(:reply) do
        Fabricate(:post_with_long_raw_content,
          topic: topic,
          user: topic.user,
        ).tap { |post| post.update!(raw: "#{post.raw} elephant") }
      end

      let(:expected_blurb) do
        "...to satisfy any test conditions that require content longer than the typical test post raw content. elephant"
      end

      it 'returns the post' do
        result = Search.execute('elephant',
          type_filter: 'topic',
          include_blurbs: true
        )

        expect(result.posts).to contain_exactly(reply)
        expect(result.blurb(reply)).to eq(expected_blurb)
      end

      it 'returns the right post and blurb for searches with phrase' do
        result = Search.execute('"elephant"',
          type_filter: 'topic',
          include_blurbs: true
        )

        expect(result.posts).to contain_exactly(reply)
        expect(result.blurb(reply)).to eq(expected_blurb)
      end

      it 'does not allow a post with repeated words to dominate the ranking' do
        category = Fabricate(:category_with_definition, name: "winter is coming")

        post = Fabricate(:post,
          raw: "I think winter will end soon",
          topic: Fabricate(:topic,
            title: "dragon john snow winter",
            category: category
          )
        )

        post2 = Fabricate(:post,
          raw: "I think #{'winter' * 20} will end soon",
          topic: Fabricate(:topic, title: "dragon john snow summer", category: category)
        )

        result = Search.execute('winter')

        expect(result.posts.pluck(:id)).to eq([
          post.id, category.topic.first_post.id, post2.id
        ])
      end

      it 'applies a small penalty to closed topic when ranking' do
        post = Fabricate(:post,
          raw: "My weekly update",
          topic: Fabricate(:topic,
            title: "A topic that will be closed",
            closed: true
          )
        )

        post2 = Fabricate(:post,
          raw: "My weekly update",
          topic: Fabricate(:topic,
            title: "A topic that will be open"
          )
        )

        result = Search.execute('weekly update')
        expect(result.posts.pluck(:id)).to eq([post2.id, post.id])
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
          result = Search.execute(topic.relative_url, search_for_id: true, type_filter: 'private_messages', guardian: Guardian.new(admin), restrict_to_archetype: Archetype.private_message)
          expect(result.posts.length).to eq(0)

          result = Search.execute(personal_message.relative_url, search_for_id: true, type_filter: 'private_messages', guardian: Guardian.new(admin), restrict_to_archetype: Archetype.private_message)
          expect(result.posts.length).to eq(1)
        end
      end
    end

    context 'security' do

      def result(current_user)
        Search.execute('hello', guardian: Guardian.new(current_user))
      end

      it 'secures results correctly' do
        category = Fabricate(:category_with_definition)

        topic.category_id = category.id
        topic.save

        category.set_permissions(staff: :full)
        category.save

        expect(result(nil).posts).not_to be_present
        expect(result(Fabricate(:user)).posts).not_to be_present
        expect(result(admin).posts).to be_present

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
    let(:category) { Fabricate(:category_with_definition, name: "monkey Category 2") }
    let(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic, raw: "snow monkey") }

    let!(:ignored_category) do
      Fabricate(:category_with_definition,
        name: "monkey Category 1",
        slug: "test",
        search_priority: Searchable::PRIORITIES[:ignore]
      )
    end

    it "should return the right categories" do
      search = Search.execute("monkey")

      expect(search.categories).to contain_exactly(
        category, ignored_category
      )

      expect(search.posts).to contain_exactly(category.topic.first_post, post)

      search = Search.execute("monkey #test")

      expect(search.posts).to contain_exactly(ignored_category.topic.first_post)
    end

    describe "with child categories" do
      let!(:child_of_ignored_category) do
        Fabricate(:category_with_definition,
          name: "monkey Category 3",
          parent_category: ignored_category
        )
      end

      let!(:post2) do
        Fabricate(:post,
          topic: Fabricate(:topic, category: child_of_ignored_category),
          raw: "snow monkey park"
        )
      end

      it 'returns the right results' do
        search = Search.execute("monkey")

        expect(search.categories).to contain_exactly(
          category, ignored_category, child_of_ignored_category
        )

        expect(search.posts).to contain_exactly(
          category.topic.first_post,
          post,
          child_of_ignored_category.topic.first_post,
          post2
        )

        search = Search.execute("snow")
        expect(search.posts).to contain_exactly(post, post2)

        category.set_permissions({})
        category.save
        search = Search.execute("monkey")

        expect(search.categories).to contain_exactly(
          ignored_category, child_of_ignored_category
        )

        expect(search.posts).to contain_exactly(
          child_of_ignored_category.topic.first_post,
          post2
        )
      end
    end

    describe 'categories with different priorities' do
      let(:category2) { Fabricate(:category_with_definition) }

      it "should return posts in the right order" do
        raw = "The pure genuine evian"
        post = Fabricate(:post, topic: category.topic, raw: raw)
        post2 = Fabricate(:post, topic: category2.topic, raw: raw)

        search = Search.execute(raw)

        expect(search.posts).to eq([post2, post])

        category.update!(search_priority: Searchable::PRIORITIES[:high])

        search = Search.execute(raw)

        expect(search.posts).to eq([post, post2])
      end
    end

  end

  context 'groups' do
    def search(user = Fabricate(:user))
      Search.execute(group.name, guardian: Guardian.new(user))
    end

    let!(:group) { Group[:trust_level_0] }

    it 'shows group' do
      expect(search.groups.map(&:name)).to eq([group.name])
    end

    context 'group visibility' do
      let!(:group) { Fabricate(:group) }

      before do
        group.update!(visibility_level: 3)
      end

      context 'staff logged in' do
        it 'shows group' do
          expect(search(admin).groups.map(&:name)).to eq([group.name])
        end
      end

      context 'non staff logged in' do
        it 'shows doesn’t show group' do
          expect(search.groups.map(&:name)).to be_empty
        end
      end
    end
  end

  context 'tags' do
    def search
      Search.execute(tag.name)
    end

    let!(:tag) { Fabricate(:tag) }
    let!(:uppercase_tag) { Fabricate(:tag, name: "HeLlO") }
    let(:tag_group) { Fabricate(:tag_group) }
    let(:category) { Fabricate(:category_with_definition) }

    context 'post searching' do
      before do
        SiteSetting.tagging_enabled = true
        DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(Fabricate.build(:admin)), [tag.name, uppercase_tag.name])
        post.topic.save
      end

      let(:post) { Fabricate(:post, raw: 'I am special post') }

      it 'can find posts with tags' do
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

      it 'can find posts with tag synonyms' do
        synonym = Fabricate(:tag, name: 'synonym', target_tag: tag)
        Jobs::ReindexSearch.new.rebuild_problem_posts
        result = Search.execute(synonym.name)
        expect(result.posts.length).to eq(1)
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

        expect(Search.execute(tag.name, guardian: Guardian.new(admin)).tags.map(&:name)).to contain_exactly(tag.name, "#{tag.name}9")
        expect(search.tags.map(&:name)).to contain_exactly(tag.name, "#{tag.name}9")
      end

      it 'includes category-restricted tags' do
        category_tag = Fabricate(:tag, name: "#{tag.name}9")
        tag_group.tags = [category_tag]
        category.set_permissions(admins: :full)
        category.allowed_tag_groups = [tag_group.name]
        category.save!

        expect(Search.execute(tag.name, guardian: Guardian.new(admin)).tags).to contain_exactly(tag, category_tag)
        expect(search.tags).to contain_exactly(tag, category_tag)
      end
    end
  end

  context 'type_filter' do

    let!(:user) { Fabricate(:user, username: 'amazing', email: 'amazing@amazing.com') }
    let!(:category) { Fabricate(:category_with_definition, name: 'amazing category', user: user) }

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
      category = Fabricate(:category_with_definition,
        search_priority: Searchable::PRIORITIES[:ignore]
      )

      topic = Fabricate(:topic, category: category)
      topic_no_cat = Fabricate(:topic)

      # includes subcategory in search
      subcategory = Fabricate(:category_with_definition, parent_category_id: category.id)
      sub_topic = Fabricate(:topic, category: subcategory)

      post = Fabricate(:post, topic: topic, user: topic.user)
      Fabricate(:post, topic: topic_no_cat, user: topic.user)
      sub_post = Fabricate(:post, raw: 'I am saying hello from a subcategory', topic: sub_topic, user: topic.user)

      search = Search.execute('hello', search_context: category)
      expect(search.posts.map(&:id)).to match_array([post.id, sub_post.id])
      expect(search.posts.length).to eq(2)
    end

    it 'can use tag as a search context' do
      tag = Fabricate(:tag, name: 'important-stuff')

      topic = Fabricate(:topic)
      topic_no_tag = Fabricate(:topic)
      Fabricate(:topic_tag, tag: tag, topic: topic)

      post = Fabricate(:post, topic: topic, user: topic.user, raw: 'This is my hello')
      Fabricate(:post, topic: topic_no_tag, user: topic.user)

      search = Search.execute('hello', search_context: tag)
      expect(search.posts.map(&:id)).to contain_exactly(post.id)
      expect(search.posts.length).to eq(1)
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
      expect(Search.execute('boom f').posts.length).to eq(0)

      expect(Search.execute('123 in:first').posts.length).to eq(1)
      expect(Search.execute('123 f').posts.length).to eq(1)

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
      post = Fabricate(:post, raw: '3.0 eta is in 2 days horrah')
      post2 = Fabricate(:post, raw: '3.0 is eta in 2 days horrah')

      expect(Search.execute('3.0 eta').posts).to contain_exactly(post, post2)
      expect(Search.execute("'3.0 eta'").posts).to contain_exactly(post, post2)
      expect(Search.execute("\"3.0 eta\"").posts).to contain_exactly(post)
      expect(Search.execute('"3.0, eta is"').posts).to eq([])
    end

    it 'can find by status' do
      public_category = Fabricate(:category, read_restricted: false)
      post = Fabricate(:post, raw: 'hi this is a test 123 123')
      topic = post.topic
      topic.update(category: public_category)

      private_category = Fabricate(:category, read_restricted: true)
      post2 = Fabricate(:post, raw: 'hi this is another test 123 123')
      second_topic = post2.topic
      second_topic.update(category: private_category)

      post3 = Fabricate(:post, raw: "another test!", user: topic.user, topic: second_topic)

      expect(Search.execute('test status:public').posts.length).to eq(1)
      expect(Search.execute('test status:closed').posts.length).to eq(0)
      expect(Search.execute('test status:open').posts.length).to eq(1)
      expect(Search.execute('test posts_count:1').posts.length).to eq(1)
      expect(Search.execute('test min_post_count:1').posts.length).to eq(1)

      topic.update(closed: true)
      second_topic.update(category: public_category)

      expect(Search.execute('test status:public').posts.length).to eq(2)
      expect(Search.execute('test status:closed').posts.length).to eq(1)
      expect(Search.execute('status:closed').posts.length).to eq(1)
      expect(Search.execute('test status:open').posts.length).to eq(1)

      topic.update(archived: true, closed: false)
      second_topic.update(closed: true)

      expect(Search.execute('test status:archived').posts.length).to eq(1)
      expect(Search.execute('test status:open').posts.length).to eq(0)

      expect(Search.execute('test status:noreplies').posts.length).to eq(1)

      expect(Search.execute('test in:likes', guardian: Guardian.new(topic.user)).posts.length).to eq(0)

      expect(Search.execute('test in:posted', guardian: Guardian.new(topic.user)).posts.length).to eq(2)

      in_created = Search.execute('test in:created', guardian: Guardian.new(topic.user)).posts
      created_by_user = Search.execute("test created:@#{topic.user.username}", guardian: Guardian.new(topic.user)).posts
      expect(in_created.length).to eq(1)
      expect(created_by_user.length).to eq(1)
      expect(in_created).to eq(created_by_user)

      expect(Search.execute("test created:@#{second_topic.user.username}", guardian: Guardian.new(topic.user)).posts.length).to eq(1)

      new_user = Fabricate(:user)
      expect(Search.execute("test created:@#{new_user.username}", guardian: Guardian.new(topic.user)).posts.length).to eq(0)

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
      category = Fabricate(:category_with_definition)

      old_topic = Fabricate(:topic,
        title: 'First Topic, testing the created_at sort',
        created_at: two_days_ago,
        category: category
      )

      latest_topic = Fabricate(:topic,
        title: 'Second Topic, testing the created_at sort',
        created_at: yesterday,
        category: category
      )

      old_relevant_topic_post = Fabricate(:post,
        topic: old_topic,
        created_at: yesterday,
        raw: 'Relevant Relevant Topic'
      )

      latest_irelevant_topic_post = Fabricate(:post,
        topic: latest_topic,
        created_at: today,
        raw: 'Not Relevant'
      )

      # Expecting the default results
      expect(Search.execute('Topic').posts).to contain_exactly(
        old_relevant_topic_post,
        latest_irelevant_topic_post,
        category.topic.first_post
      )

      # Expecting the ordered by topic creation results
      expect(Search.execute('Topic order:latest_topic').posts).to contain_exactly(
        latest_irelevant_topic_post,
        old_relevant_topic_post,
        category.topic.first_post
      )
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
      category = Fabricate(:category_with_definition, name: 'category 24', slug: 'cateGory-24')
      topic = Fabricate(:topic, created_at: 3.months.ago, category: category)
      post = Fabricate(:post, raw: 'Sams first post', topic: topic)

      expect(Search.execute('sams post #categoRy-24').posts.length).to eq(1)
      expect(Search.execute("sams post category:#{category.id}").posts.length).to eq(1)
      expect(Search.execute('sams post #categoRy-25').posts.length).to eq(0)

      sub_category = Fabricate(:category_with_definition, name: 'sub category', slug: 'sub-category', parent_category_id: category.id)
      second_topic = Fabricate(:topic, created_at: 3.months.ago, category: sub_category)
      Fabricate(:post, raw: 'sams second post', topic: second_topic)

      expect(Search.execute("sams post category:categoRY-24").posts.length).to eq(2)
      expect(Search.execute("sams post category:=cAtegory-24").posts.length).to eq(1)

      expect(Search.execute("sams post #category-24").posts.length).to eq(2)
      expect(Search.execute("sams post #=category-24").posts.length).to eq(1)
      expect(Search.execute("sams post #sub-category").posts.length).to eq(1)

      expect(Search.execute("sams post #categoRY-24:SUB-category").posts.length)
        .to eq(1)

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
      fab!(:tag1) { Fabricate(:tag, name: 'lunch') }
      fab!(:tag2) { Fabricate(:tag, name: 'eggs') }
      fab!(:tag3) { Fabricate(:tag, name: 'sandwiches') }

      fab!(:tag_group) do
        group = TagGroup.create!(name: 'mid day')
        TagGroupMembership.create!(tag_id: tag1.id, tag_group_id: group.id)
        TagGroupMembership.create!(tag_id: tag3.id, tag_group_id: group.id)
        group
      end

      fab!(:topic1) { Fabricate(:topic, tags: [tag2, Fabricate(:tag)]) }
      fab!(:topic2) { Fabricate(:topic, tags: [tag2]) }
      fab!(:topic3) { Fabricate(:topic, tags: [tag1, tag2]) }
      fab!(:topic4) { Fabricate(:topic, tags: [tag1, tag2, tag3]) }
      fab!(:topic5) { Fabricate(:topic, tags: [tag2, tag3]) }

      def indexed_post(*args)
        SearchIndexer.enable
        Fabricate(:post, *args)
      end

      fab!(:post1) { indexed_post(topic: topic1) }
      fab!(:post2) { indexed_post(topic: topic2) }
      fab!(:post3) { indexed_post(topic: topic3) }
      fab!(:post4) { indexed_post(topic: topic4) }
      fab!(:post5) { indexed_post(topic: topic5) }

      it 'can find posts by tag group' do
        expect(Search.execute('#mid-day').posts.map(&:id)).to (
          contain_exactly(post3.id, post4.id, post5.id)
        )
      end

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
        cat1 = Fabricate(:category_with_definition, name: 'food')
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
      str = +" grigio:babel deprecated? "
      str << "page page on Atmosphere](https://atmospherejs.com/grigio/babel)xxx: aaa.js:222 aaa'\"bbb"

      ts_query = Search.ts_query(term: str, ts_config: "simple")
      expect { DB.exec(+"SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error

      ts_query = Search.ts_query(term: "foo.bar/'&baz", ts_config: "simple")
      expect { DB.exec(+"SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error
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

      results = Search.execute('title t')
      expect(results.posts.length).to eq(1)

      results = Search.execute('first in:title')
      expect(results.posts.length).to eq(0)

      results = Search.execute('first t')
      expect(results.posts.length).to eq(0)
    end

    it 'works irrespective of the order' do
      topic = Fabricate(:topic, title: "A topic about Discourse")
      Fabricate(:post, topic: topic, raw: "This is another post")
      topic2 = Fabricate(:topic, title: "This is another topic")
      Fabricate(:post, topic: topic2, raw: "Discourse is awesome")

      results = Search.execute('Discourse in:title status:open')
      expect(results.posts.length).to eq(1)

      results = Search.execute('in:title status:open Discourse')
      expect(results.posts.length).to eq(1)
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

  context 'in:tagged' do
    it 'allows for searching by presence of any tags' do
      topic = Fabricate(:topic, title: 'I am testing a tagged search')
      _post = Fabricate(:post, topic: topic, raw: 'this is the first post')
      tag = Fabricate(:tag)
      topic_tag = Fabricate(:topic_tag, topic: topic, tag: tag)

      results = Search.execute('in:untagged')
      expect(results.posts.length).to eq(0)

      results = Search.execute('in:tagged')
      expect(results.posts.length).to eq(1)
    end
  end

  context 'in:untagged' do
    it 'allows for searching by presence of no tags' do
      topic = Fabricate(:topic, title: 'I am testing a untagged search')
      _post = Fabricate(:post, topic: topic, raw: 'this is the first post')

      results = Search.execute('in:untagged')
      expect(results.posts.length).to eq(1)

      results = Search.execute('in:tagged')
      expect(results.posts.length).to eq(0)
    end
  end

end
