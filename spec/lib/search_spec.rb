# frozen_string_literal: true

RSpec.describe Search do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:topic)

  before do
    SearchIndexer.enable
    Jobs.run_immediately!
  end

  describe ".need_segmenting?" do
    subject(:search) { described_class }

    context "when data only contains digits" do
      let(:data) { "510" }

      it { is_expected.not_to be_need_segmenting(data) }
    end

    context "when data does not only contain digits" do
      context "when data is a full URL" do
        let(:data) { "http://localhost/t/-/510" }

        it { is_expected.not_to be_need_segmenting(data) }
      end

      context "when data is a path" do
        let(:data) { "/t/-/510" }

        it { is_expected.not_to be_need_segmenting(data) }
      end

      context "when data makes `URI#path` return `nil`" do
        let(:data) { "in:solved%20category:50%20order:likes" }

        it "doesn’t raise an error" do
          expect { search.need_segmenting?(data) }.not_to raise_error
        end
      end

      context "when data is something else" do
        let(:data) { "text" }

        it { is_expected.to be_need_segmenting(data) }
      end
    end
  end

  describe "#ts_config" do
    it "maps locales to correct Postgres dictionaries" do
      expect(Search.ts_config).to eq("english")
      expect(Search.ts_config("en")).to eq("english")
      expect(Search.ts_config("en_GB")).to eq("english")
      expect(Search.ts_config("pt_BR")).to eq("portuguese")
      expect(Search.ts_config("tr")).to eq("turkish")
      expect(Search.ts_config("xx")).to eq("simple")
    end
  end

  describe "#GroupedSearchResults.blurb_for" do
    it "strips audio and video URLs from search blurb" do
      cooked = <<~RAW
        link to an external page: https://google.com/?u=bar

        link to an audio file: https://somesite.com/content/file123.m4a

        link to a video file: https://somesite.com/content/somethingelse.MOV
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq(
        "link to an external page: https://google.com/?u=bar link to an audio file: #{I18n.t("search.audio")} link to a video file: #{I18n.t("search.video")}",
      )
    end

    it "strips URLs correctly when blurb is longer than limit" do
      cooked = <<~RAW
        Here goes a test cooked with enough characters to hit the blurb limit.

        Something is very interesting about this audio file.

        http://localhost/uploads/default/original/1X/90adc0092b30c04b761541bc0322d0dce3d896e7.m4a
      RAW

      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq(
        "Here goes a test cooked with enough characters to hit the blurb limit. Something is very interesting about this audio file. #{I18n.t("search.audio")}",
      )
    end

    it "does not fail on bad URLs" do
      cooked = <<~RAW
        invalid URL: http:error] should not trip up blurb generation.
      RAW
      result = Search::GroupedSearchResults.blurb_for(cooked: cooked)
      expect(result).to eq("invalid URL: http:error] should not trip up blurb generation.")
    end
  end

  describe "#execute" do
    before { SiteSetting.tagging_enabled = true }

    context "with staff tags" do
      fab!(:hidden_tag) { Fabricate(:tag) }
      let!(:staff_tag_group) do
        Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
      end
      fab!(:topic) { Fabricate(:topic, tags: [hidden_tag]) }
      fab!(:post) { Fabricate(:post, topic: topic) }

      before do
        SiteSetting.tagging_enabled = true

        SearchIndexer.enable
        SearchIndexer.index(hidden_tag, force: true)
        SearchIndexer.index(topic, force: true)
      end

      it "are visible to staff users" do
        result = Search.execute(hidden_tag.name, guardian: Guardian.new(Fabricate(:admin)))
        expect(result.tags).to contain_exactly(hidden_tag)
      end

      it "are hidden to regular users" do
        result = Search.execute(hidden_tag.name, guardian: Guardian.new(Fabricate(:user)))
        expect(result.tags).to contain_exactly()
      end
    end

    context "with accents" do
      fab!(:post_1) { Fabricate(:post, raw: "Cette ****** d'art n'est pas une œuvre") }
      fab!(:post_2) { Fabricate(:post, raw: "Cette oeuvre d'art n'est pas une *****") }

      before { SearchIndexer.enable }

      after { SearchIndexer.disable }

      it "removes them if search_ignore_accents" do
        SiteSetting.search_ignore_accents = true
        [post_1, post_2].each { |post| SearchIndexer.index(post.topic, force: true) }

        expect(Search.execute("oeuvre").posts).to contain_exactly(post_1, post_2)
        expect(Search.execute("œuvre").posts).to contain_exactly(post_1, post_2)
      end

      it "does not remove them if not search_ignore_accents" do
        SiteSetting.search_ignore_accents = false
        [post_1, post_2].each { |post| SearchIndexer.index(post.topic, force: true) }

        expect(Search.execute("œuvre").posts).to contain_exactly(post_1)
        expect(Search.execute("oeuvre").posts).to contain_exactly(post_2)
      end
    end

    context "when search_ranking_weights site setting has been configured" do
      fab!(:topic) { Fabricate(:topic, title: "Some random topic title start") }
      fab!(:topic2) { Fabricate(:topic, title: "Some random topic title") }
      fab!(:post1) { Fabricate(:post, raw: "start", topic: topic) }
      fab!(:post2) { Fabricate(:post, raw: "#{"start " * 100}", topic: topic2) }

      before do
        SearchIndexer.enable
        SiteSetting.max_duplicate_search_index_terms = -1
        SiteSetting.prioritize_exact_search_title_match = false
        [post1, post2].each { |post| SearchIndexer.index(post, force: true) }
      end

      after { SearchIndexer.disable }

      it "should apply the custom ranking weights correctly" do
        expect(Search.execute("start").posts).to eq([post2, post1])

        SiteSetting.search_ranking_weights = "{0.00001,0.2,0.4,1.0}"

        expect(Search.execute("start").posts).to eq([post1, post2])
      end
    end
  end

  describe "custom_eager_load" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    before do
      SearchIndexer.enable
      SearchIndexer.index(topic, force: true)
    end

    it "includes custom tables" do
      begin
        SiteSetting.tagging_enabled = false
        expect(Search.execute("test").posts[0].topic.association(:category).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:tags).loaded?).to be false

        SiteSetting.tagging_enabled = true
        Search.custom_topic_eager_load([:topic_users])
        Search.custom_topic_eager_load() { [:bookmarks] }

        expect(Search.execute("test").posts[0].topic.association(:tags).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:topic_users).loaded?).to be true
        expect(Search.execute("test").posts[0].topic.association(:bookmarks).loaded?).to be true
      ensure
        SiteSetting.tagging_enabled = false
        Search.instance_variable_set(:@custom_topic_eager_loads, [])
      end
    end
  end

  describe "users" do
    fab!(:user) { Fabricate(:user, username: "DonaldDuck") }
    fab!(:user2) { Fabricate(:user) }

    before do
      SearchIndexer.enable
      SearchIndexer.index(user, force: true)
    end

    it "finds users by their names or custom fields" do
      result = Search.execute("donaldduck", guardian: Guardian.new(user2))
      expect(result.users).to contain_exactly(user)

      user_field = Fabricate(:user_field, name: "custom field")
      UserCustomField.create!(user: user, value: "test", name: "user_field_#{user_field.id}")
      Jobs::ReindexSearch.new.execute({})
      result = Search.execute("test", guardian: Guardian.new(user2))
      expect(result.users).to be_empty

      user_field.update!(searchable: true)
      Jobs::ReindexSearch.new.execute({})
      result = Search.execute("test", guardian: Guardian.new(user2))
      expect(result.users).to contain_exactly(user)

      user_field2 = Fabricate(:user_field, name: "another custom field", searchable: true)
      UserCustomField.create!(
        user: user,
        value: "longer test",
        name: "user_field_#{user_field2.id}",
      )
      UserCustomField.create!(
        user: user2,
        value: "second user test",
        name: "user_field_#{user_field2.id}",
      )
      SearchIndexer.index(user, force: true)
      SearchIndexer.index(user2, force: true)
      result = Search.execute("test", guardian: Guardian.new(user2))

      expect(result.users.find { |u| u.id == user.id }.custom_data).to eq(
        [
          { name: "custom field", value: "test" },
          { name: "another custom field", value: "longer test" },
        ],
      )
      expect(result.users.find { |u| u.id == user2.id }.custom_data).to eq(
        [{ name: "another custom field", value: "second user test" }],
      )
    end

    context "when using SiteSetting.enable_listing_suspended_users_on_search" do
      fab!(:suspended_user) do
        Fabricate(
          :user,
          username: "revolver_ocelot",
          suspended_at: Time.now,
          suspended_till: 5.days.from_now,
        )
      end

      before { SearchIndexer.index(suspended_user, force: true) }

      it "should list suspended users to regular users if the setting is enabled" do
        SiteSetting.enable_listing_suspended_users_on_search = true

        result = Search.execute("revolver_ocelot", guardian: Guardian.new(user))
        expect(result.users).to contain_exactly(suspended_user)
      end

      it "shouldn't list suspended users to regular users if the setting is disabled" do
        SiteSetting.enable_listing_suspended_users_on_search = false

        result = Search.execute("revolver_ocelot", guardian: Guardian.new(user))
        expect(result.users).to be_empty
      end

      it "should list suspended users to admins regardless of the setting" do
        SiteSetting.enable_listing_suspended_users_on_search = false

        result = Search.execute("revolver_ocelot", guardian: Guardian.new(Fabricate(:admin)))
        expect(result.users).to contain_exactly(suspended_user)
      end
    end
  end

  describe "categories" do
    it "finds topics in sub-sub-categories" do
      SiteSetting.max_category_nesting = 3

      category = Fabricate(:category_with_definition)
      subcategory = Fabricate(:category_with_definition, parent_category_id: category.id)
      subsubcategory = Fabricate(:category_with_definition, parent_category_id: subcategory.id)

      topic = Fabricate(:topic, category: subsubcategory)
      post = Fabricate(:post, topic: topic)

      SearchIndexer.enable
      SearchIndexer.index(post, force: true)

      expect(Search.execute("test ##{category.slug}").posts).to contain_exactly(post)
      expect(Search.execute("test ##{category.slug}:#{subcategory.slug}").posts).to contain_exactly(
        post,
      )
      expect(Search.execute("test ##{subcategory.slug}").posts).to contain_exactly(post)
      expect(
        Search.execute("test ##{subcategory.slug}:#{subsubcategory.slug}").posts,
      ).to contain_exactly(post)
      expect(Search.execute("test ##{subsubcategory.slug}").posts).to contain_exactly(post)

      expect(Search.execute("test #=#{category.slug}").posts).to be_empty
      expect(Search.execute("test #=#{category.slug}:#{subcategory.slug}").posts).to be_empty
      expect(Search.execute("test #=#{subcategory.slug}").posts).to be_empty
      expect(
        Search.execute("test #=#{subcategory.slug}:#{subsubcategory.slug}").posts,
      ).to contain_exactly(post)
      expect(Search.execute("test #=#{subsubcategory.slug}").posts).to contain_exactly(post)
    end
  end

  describe "post indexing" do
    fab!(:category) { Fabricate(:category_with_definition, name: "america") }
    fab!(:topic) { Fabricate(:topic, title: "sam saffron test topic", category: category) }
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    let!(:post) do
      Fabricate(
        :post,
        topic: topic,
        raw: 'this <b>fun test</b> <img src="bla" title="my image">',
        user: user,
      )
    end
    let!(:post2) { Fabricate(:post, topic: topic, user: user) }

    it "should index correctly" do
      search_data = post.post_search_data.search_data

      expect(search_data).to match(/fun/)
      expect(search_data).to match(/sam/)
      expect(search_data).to match(/america/)

      expect do topic.update!(title: "harpi is the new title") end.to change {
        post2.reload.post_search_data.version
      }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION)

      expect(post.post_search_data.reload.search_data).to match(/harpi/)
    end

    it "should update posts index when topic category changes" do
      expect do topic.update!(category: Fabricate(:category)) end.to change {
        post.reload.post_search_data.version
      }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION).and change {
              post2.reload.post_search_data.version
            }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION)
    end

    it "should update posts index when topic tags changes" do
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)

      expect do
        DiscourseTagging.tag_topic_by_names(topic, Guardian.new(admin), [tag.name])
        topic.save!
      end.to change { post.reload.post_search_data.version }.from(
        SearchIndexer::POST_INDEX_VERSION,
      ).to(SearchIndexer::REINDEX_VERSION).and change {
              post2.reload.post_search_data.version
            }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION)

      expect(topic.tags).to eq([tag])
    end
  end

  describe "user indexing" do
    before do
      @user = Fabricate(:user, username: "fred", name: "bob jones")
      @indexed = @user.user_search_data.search_data
    end

    it "should pick up on data" do
      expect(@indexed).to match(/fred/)
      expect(@indexed).to match(/jone/)
    end
  end

  describe "category indexing" do
    let!(:category) { Fabricate(:category_with_definition, name: "america") }
    let!(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic) }
    let!(:post2) { Fabricate(:post, topic: topic) }
    let!(:post3) { Fabricate(:post) }

    it "should index correctly" do
      expect(category.category_search_data.search_data).to match(/america/)
    end

    it "should update posts index when category name changes" do
      expect do category.update!(name: "some new name") end.to change {
        post.reload.post_search_data.version
      }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION).and change {
              post2.reload.post_search_data.version
            }.from(SearchIndexer::POST_INDEX_VERSION).to(SearchIndexer::REINDEX_VERSION)

      expect(post3.post_search_data.version).to eq(SearchIndexer::POST_INDEX_VERSION)
    end
  end

  it "strips zero-width characters from search terms" do
    term =
      "\u0063\u0061\u0070\u0079\u200b\u200c\u200d\ufeff\u0062\u0061\u0072\u0061".encode("UTF-8")

    expect(term == "capybara").to eq(false)

    search = Search.new(term)
    expect(search.valid?).to eq(true)
    expect(search.term).to eq("capybara")
    expect(search.clean_term).to eq("capybara")
  end

  it "replaces curly quotes to regular quotes in search terms" do
    term = "“discourse”"

    expect(term == '"discourse"').to eq(false)

    search = Search.new(term)
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('"discourse"')
    expect(search.clean_term).to eq('"discourse"')
  end

  it "does not search when the search term is too small" do
    search = Search.new("evil", min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(false)
    expect(search.term).to eq("")
  end

  it "needs at least one term that hits the length" do
    search = Search.new("a b c d", min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(false)
    expect(search.term).to eq("")
  end

  it "searches for quoted short terms" do
    search = Search.new('"a b c d"', min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(true)
    expect(search.term).to eq('"a b c d"')
  end

  it "searches for short terms if one hits the length" do
    search = Search.new("a b c okaylength", min_search_term_length: 5)
    search.execute
    expect(search.valid?).to eq(true)
    expect(search.term).to eq("a b c okaylength")
  end

  describe "query sanitization" do
    let!(:post) { Fabricate(:post, raw: "hello world") }

    it "escapes backslash" do
      expect(Search.execute('hello\\').posts).to contain_exactly(post)
    end

    it "escapes single quote" do
      expect(Search.execute("hello'").posts).to contain_exactly(post)
    end

    it "escapes non-alphanumeric characters" do
      expect(Search.execute('hello :!$);}]>@\#\"\'').posts).to contain_exactly(post)
    end
  end

  it "works when given two terms with spaces" do
    expect { Search.execute("evil trout") }.not_to raise_error
  end

  describe "users" do
    let!(:user) { Fabricate(:user) }
    let(:result) { Search.execute("bruce", type_filter: "user") }

    it "returns a result" do
      expect(result.users.length).to eq(1)
      expect(result.users[0].id).to eq(user.id)
    end

    context "when hiding user profiles" do
      before { SiteSetting.hide_user_profiles_from_public = true }

      it "returns no result for anon" do
        expect(result.users.length).to eq(0)
      end

      it "returns a result for logged in users" do
        result = Search.execute("bruce", type_filter: "user", guardian: Guardian.new(user))
        expect(result.users.length).to eq(1)
      end
    end
  end

  describe "inactive users" do
    let!(:inactive_user) { Fabricate(:inactive_user, active: false) }
    let(:result) { Search.execute("bruce") }

    it "does not return a result" do
      expect(result.users.length).to eq(0)
    end
  end

  describe "staged users" do
    let(:staged) { Fabricate(:staged) }
    let(:result) { Search.execute(staged.username) }

    it "does not return a result" do
      expect(result.users.length).to eq(0)
    end
  end

  describe "private messages" do
    let!(:post) { Fabricate(:private_message_post) }

    let(:topic) { post.topic }

    let!(:reply) do
      Fabricate(
        :private_message_post,
        topic: post.topic,
        raw: "hello from mars, we just landed",
        user: post.user,
      )
    end

    let!(:post2) { Fabricate(:private_message_post, raw: "another secret pm from mars, testing") }

    it "searches correctly as an admin" do
      results =
        Search.execute("mars", type_filter: "private_messages", guardian: Guardian.new(admin))

      expect(results.posts).to eq([])
    end

    it "searches correctly as an admin given another user's context" do
      results =
        Search.execute(
          "mars",
          type_filter: "private_messages",
          search_context: reply.user,
          guardian: Guardian.new(admin),
        )

      expect(results.posts).to contain_exactly(reply)
    end

    it "raises the right error when a normal user searches for another user's context" do
      expect do
        Search.execute(
          "mars",
          search_context: reply.user,
          type_filter: "private_messages",
          guardian: Guardian.new(Fabricate(:user)),
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "searches correctly as a user" do
      results =
        Search.execute("mars", type_filter: "private_messages", guardian: Guardian.new(reply.user))

      expect(results.posts).to contain_exactly(reply)
    end

    it "searches correctly for a user with no private messages" do
      results =
        Search.execute(
          "mars",
          type_filter: "private_messages",
          guardian: Guardian.new(Fabricate(:user)),
        )

      expect(results.posts).to eq([])
    end

    it "searches correctly" do
      expect do Search.execute("mars", type_filter: "private_messages") end.to raise_error(
        Discourse::InvalidAccess,
      )

      results =
        Search.execute("mars", type_filter: "private_messages", guardian: Guardian.new(reply.user))

      expect(results.posts).to contain_exactly(reply)

      results = Search.execute("mars", search_context: topic, guardian: Guardian.new(reply.user))

      expect(results.posts).to contain_exactly(reply)

      # can search group PMs as well as non admin
      user = Fabricate(:user)
      group = Fabricate.build(:group)
      group.add(user)
      group.save!

      TopicAllowedGroup.create!(group_id: group.id, topic_id: topic.id)

      [
        "mars in:personal",
        "mars IN:PERSONAL",
        "in:messages mars",
        "IN:MESSAGES mars",
      ].each do |query|
        results = Search.execute(query, guardian: Guardian.new(user))
        expect(results.posts).to contain_exactly(reply)
      end
    end

    context "with personal_messages filter" do
      it "does not allow a normal user to search for personal messages of another user" do
        expect do
          Search.execute(
            "mars personal_messages:#{post.user.username}",
            guardian: Guardian.new(Fabricate(:user)),
          )
        end.to raise_error(Discourse::InvalidAccess)
      end

      it "searches correctly for the PM of the given user" do
        results =
          Search.execute(
            "mars personal_messages:#{post.user.username}",
            guardian: Guardian.new(admin),
          )

        expect(results.posts).to contain_exactly(reply)
      end

      it "returns the right results if username is invalid" do
        results =
          Search.execute("mars personal_messages:random_username", guardian: Guardian.new(admin))

        expect(results.posts).to eq([])
      end
    end

    context "with all-pms flag" do
      it "returns matching PMs if the user is an admin" do
        results = Search.execute("mars in:all-pms", guardian: Guardian.new(admin))

        expect(results.posts).to include(reply, post2)
      end

      it "returns nothing if the user is not an admin" do
        results = Search.execute("mars in:all-pms", guardian: Guardian.new(Fabricate(:user)))

        expect(results.posts).to be_empty
      end

      it "returns nothing if the user is a moderator" do
        results = Search.execute("mars in:all-pms", guardian: Guardian.new(Fabricate(:moderator)))

        expect(results.posts).to be_empty
      end
    end

    context "with personal-direct and group_messages flags" do
      let!(:current) do
        Fabricate(:user, admin: true, username: "current_user", refresh_auto_groups: true)
      end
      let!(:participant) { Fabricate(:user, username: "participant_1", refresh_auto_groups: true) }
      let!(:participant_2) do
        Fabricate(:user, username: "participant_2", refresh_auto_groups: true)
      end
      let!(:non_participant) do
        Fabricate(:user, username: "non_participant", refresh_auto_groups: true)
      end

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
          group.users.each { |u| Fabricate(:post, user: u, topic: pm) }
        end
        pm.reload
      end

      context "with personal-direct flag" do
        it "can find all direct PMs of the current user" do
          pm = create_pm(users: [current, participant])
          _pm_2 = create_pm(users: [participant_2, participant])
          pm_3 = create_pm(users: [participant, current])
          pm_4 = create_pm(users: [participant_2, current])

          %w[in:personal-direct In:PeRsOnAl-DiReCt].each do |query|
            results = Search.execute(query, guardian: Guardian.new(current))
            expect(results.posts.size).to eq(3)
            expect(results.posts.map(&:topic_id)).to eq([pm_4.id, pm_3.id, pm.id])
          end
        end

        it "can filter direct PMs by @username" do
          pm = create_pm(users: [current, participant])
          pm_2 = create_pm(users: [participant, current])
          pm_3 = create_pm(users: [participant_2, current])
          [
            "@#{participant.username} in:personal-direct",
            "@#{participant.username} iN:pErSoNaL-dIrEcT",
          ].each do |query|
            results = Search.execute(query, guardian: Guardian.new(current))
            expect(results.posts.size).to eq(2)
            expect(results.posts.map(&:topic_id)).to contain_exactly(pm_2.id, pm.id)
            expect(results.posts.map(&:user_id).uniq).to eq([participant.id])
          end

          results = Search.execute("@me in:personal-direct", guardian: Guardian.new(current))
          expect(results.posts.size).to eq(3)
          expect(results.posts.map(&:topic_id)).to contain_exactly(pm_3.id, pm_2.id, pm.id)
          expect(results.posts.map(&:user_id).uniq).to eq([current.id])
        end

        it "doesn't include PMs that have more than 2 participants" do
          _pm = create_pm(users: [current, participant, participant_2])
          results =
            Search.execute(
              "@#{participant.username} in:personal-direct",
              guardian: Guardian.new(current),
            )
          expect(results.posts.size).to eq(0)
        end

        it "doesn't include PMs that have groups" do
          _pm = create_pm(users: [current, participant], group: group)
          results =
            Search.execute(
              "@#{participant.username} in:personal-direct",
              guardian: Guardian.new(current),
            )
          expect(results.posts.size).to eq(0)
        end
      end

      context "with group_messages flag" do
        it "returns results correctly for a PM in a given group" do
          pm = create_pm(users: [participant, participant_2], group: group)

          results = Search.execute("group_messages:#{group.name}", guardian: Guardian.new(current))
          expect(results.posts).to contain_exactly(pm.first_post)

          results =
            Search.execute("secret group_messages:#{group.name}", guardian: Guardian.new(current))
          expect(results.posts).to contain_exactly(pm.first_post)
        end

        it "returns nothing if user is not a group member" do
          _pm = create_pm(users: [current, participant], group: group)

          results =
            Search.execute("group_messages:#{group.name}", guardian: Guardian.new(non_participant))
          expect(results.posts.size).to eq(0)

          # even for admins
          results = Search.execute("group_messages:#{group.name}", guardian: Guardian.new(admin))
          expect(results.posts.size).to eq(0)
        end

        it "returns nothing if group has messages disabled" do
          _pm = create_pm(users: [current, participant], group: group)
          group.update!(has_messages: false)

          results = Search.execute("group_messages:#{group.name}", guardian: Guardian.new(current))
          expect(results.posts.size).to eq(0)
        end

        it "is correctly scoped to a given group" do
          wrong_group = Fabricate(:group, has_messages: true)
          pm = create_pm(users: [current, participant], group: group)

          results = Search.execute("group_messages:#{group.name}", guardian: Guardian.new(current))
          expect(results.posts).to contain_exactly(pm.first_post)

          results =
            Search.execute("group_messages:#{wrong_group.name}", guardian: Guardian.new(current))
          expect(results.posts.size).to eq(0)
        end
      end
    end

    context "with all topics" do
      let!(:u1) { Fabricate(:user, username: "fred", name: "bob jones", email: "fred@bar.baz") }
      let!(:u2) { Fabricate(:user, username: "bob", name: "fred jones", email: "bob@bar.baz") }
      let!(:u3) { Fabricate(:user, username: "jones", name: "bob fred", email: "jones@bar.baz") }
      let!(:u4) do
        Fabricate(:user, username: "alice", name: "bob fred", email: "alice@bar.baz", admin: true)
      end

      let!(:public_topic) { Fabricate(:topic, user: u1) }
      let!(:public_post1) do
        Fabricate(
          :post,
          topic: public_topic,
          raw: "what do you want for breakfast?  ham and eggs?",
          user: u1,
        )
      end
      let!(:public_post2) { Fabricate(:post, topic: public_topic, raw: "ham and spam", user: u2) }

      let!(:private_topic) do
        Fabricate(:topic, user: u1, category_id: nil, archetype: "private_message")
      end
      let!(:private_post1) do
        Fabricate(
          :post,
          topic: private_topic,
          raw: "what do you want for lunch?  ham and cheese?",
          user: u1,
        )
      end
      let!(:private_post2) do
        Fabricate(:post, topic: private_topic, raw: "cheese and spam", user: u2)
      end

      it "finds private messages" do
        TopicAllowedUser.create!(user_id: u1.id, topic_id: private_topic.id)
        TopicAllowedUser.create!(user_id: u2.id, topic_id: private_topic.id)

        # case insensitive only
        results = Search.execute("iN:aLL cheese", guardian: Guardian.new(u1))
        expect(results.posts).to contain_exactly(private_post1)

        # private only
        results = Search.execute("in:all cheese", guardian: Guardian.new(u1))
        expect(results.posts).to contain_exactly(private_post1)

        # public only
        results = Search.execute("in:all eggs", guardian: Guardian.new(u1))
        expect(results.posts).to contain_exactly(public_post1)

        # both
        results = Search.execute("in:all spam", guardian: Guardian.new(u1))
        expect(results.posts).to contain_exactly(public_post2, private_post2)

        # for anon
        results = Search.execute("in:all spam", guardian: Guardian.new)
        expect(results.posts).to contain_exactly(public_post2)

        # nonparticipatory user
        results = Search.execute("in:all cheese", guardian: Guardian.new(u3))
        expect(results.posts.empty?).to eq(true)

        results = Search.execute("in:all eggs", guardian: Guardian.new(u3))
        expect(results.posts).to contain_exactly(public_post1)

        results = Search.execute("in:all spam", guardian: Guardian.new(u3))
        expect(results.posts).to contain_exactly(public_post2)

        # Admin doesn't see private topic
        results = Search.execute("in:all spam", guardian: Guardian.new(u4))
        expect(results.posts).to contain_exactly(public_post2)

        # same keyword for different users
        results = Search.execute("in:all ham", guardian: Guardian.new(u1))
        expect(results.posts).to contain_exactly(public_post1, private_post1)

        results = Search.execute("in:all ham", guardian: Guardian.new(u2))
        expect(results.posts).to contain_exactly(public_post1, private_post1)

        results = Search.execute("in:all ham", guardian: Guardian.new(u3))
        expect(results.posts).to contain_exactly(public_post1)
      end
    end
  end

  context "with posts" do
    fab!(:post) do
      SearchIndexer.enable
      Fabricate(:post)
    end

    let(:topic) { post.topic }

    let!(:reply) do
      Fabricate(:post_with_long_raw_content, topic: topic, user: topic.user).tap do |post|
        post.update!(raw: "#{post.raw} elephant")
      end
    end

    let(:expected_blurb) do
      "#{Search::GroupedSearchResults::OMISSION}hundred characters to satisfy any test conditions that require content longer than the typical test post raw content. It really is some long content, folks. <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">elephant</span>"
    end

    it "returns the post" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      result = Search.execute("elephant", type_filter: "topic", include_blurbs: true)

      expect(result.posts.map(&:id)).to contain_exactly(reply.id)

      post = result.posts.first

      expect(result.blurb(post)).to eq(expected_blurb)
      expect(post.topic_title_headline).to eq(topic.fancy_title)
    end

    it "only applies highlighting to the first #{Search::MAX_LENGTH_FOR_HEADLINE} characters" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      reply.update!(raw: "#{"a" * Search::MAX_LENGTH_FOR_HEADLINE} #{reply.raw}")

      result = Search.execute("elephant")

      expect(result.posts.map(&:id)).to contain_exactly(reply.id)

      post = result.posts.first

      expect(post.headline.include?("elephant")).to eq(false)
    end

    it "does not truncate topic title when applying highlights" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      topic = reply.topic
      topic.update!(
        title: "#{"very " * 7}long topic title with our search term in the middle of the title",
      )

      result = Search.execute("search term")

      expect(result.posts.first.topic_title_headline).to eq(<<~HTML.chomp)
        Very very very very very very very long topic title with our <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">search</span> <span class=\"#{Search::HIGHLIGHT_CSS_CLASS}\">term</span> in the middle of the title
      HTML
    end

    it "limits the search headline to #{Search::GroupedSearchResults::BLURB_LENGTH} characters" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      reply.update!(raw: "#{"a" * Search::GroupedSearchResults::BLURB_LENGTH} elephant")

      result = Search.execute("elephant")

      expect(result.posts.map(&:id)).to contain_exactly(reply.id)

      post = result.posts.first

      expect(result.blurb(post)).to eq(
        "#{"a" * Search::GroupedSearchResults::BLURB_LENGTH}#{Search::GroupedSearchResults::OMISSION}",
      )
    end

    it "returns the right post and blurb for searches with phrase" do
      SiteSetting.use_pg_headlines_for_excerpt = true

      result = Search.execute('"elephant"', type_filter: "topic", include_blurbs: true)

      expect(result.posts.map(&:id)).to contain_exactly(reply.id)
      expect(result.blurb(result.posts.first)).to eq(expected_blurb)
    end

    it "applies a small penalty to closed topics and archived topics when ranking" do
      archived_post =
        Fabricate(
          :post,
          raw: "My weekly update",
          topic:
            Fabricate(:topic, title: "A topic that will be archived", archived: true, closed: true),
        )

      closed_post =
        Fabricate(
          :post,
          raw: "My weekly update",
          topic: Fabricate(:topic, title: "A topic that will be closed", closed: true),
        )

      open_post =
        Fabricate(
          :post,
          raw: "My weekly update",
          topic: Fabricate(:topic, title: "A topic that will be open"),
        )

      result = Search.execute("weekly update")
      expect(result.posts.pluck(:id)).to eq([open_post.id, closed_post.id, archived_post.id])
    end

    it "can find posts by searching for a url prefix" do
      post = Fabricate(:post, raw: "checkout the amazing domain https://happy.sappy.com")

      results = Search.execute("happy")
      expect(results.posts.count).to eq(1)
      expect(results.posts.first.id).to eq(post.id)

      results = Search.execute("sappy")
      expect(results.posts.count).to eq(1)
      expect(results.posts.first.id).to eq(post.id)
    end

    it "aggregates searches in a topic by returning the post with the lowest post number" do
      post = Fabricate(:post, topic: topic, raw: "this is a play post")
      _post2 = Fabricate(:post, topic: topic, raw: "play play playing played play")
      post3 = Fabricate(:post, raw: "this is a play post")

      5.times { Fabricate(:post, topic: topic, raw: "play playing played") }

      results = Search.execute("play")

      expect(results.posts.map(&:id)).to eq([post.id, post3.id])
    end

    it "is able to search with an offset when configured" do
      post_1 = Fabricate(:post, raw: "this is a play post")
      SiteSetting.search_recent_regular_posts_offset_post_id = post_1.id + 1

      results = Search.execute("play post")

      expect(results.posts).to eq([post_1])

      post_2 = Fabricate(:post, raw: "this is another play post")

      SiteSetting.search_recent_regular_posts_offset_post_id = post_2.id

      results = Search.execute("play post")

      expect(results.posts.map(&:id)).to eq([post_2.id, post_1.id])
    end

    it "allows staff and members of whisperers group to search for whispers" do
      whisperers_group = Fabricate(:group)
      user = Fabricate(:user)
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}|#{whisperers_group.id}"

      post.update!(post_type: Post.types[:whisper], raw: "this is a tiger")

      results = Search.execute("tiger")

      expect(results.posts).to eq([])

      results = Search.execute("tiger", guardian: Guardian.new(admin))

      expect(results.posts).to eq([post])

      results = Search.execute("tiger", guardian: Guardian.new(user))
      expect(results.posts).to eq([])

      user.groups << whisperers_group
      results = Search.execute("tiger", guardian: Guardian.new(user))
      expect(results.posts).to eq([post])
    end

    it "does not return hidden posts" do
      Fabricate(:post, raw: "Can you see me? I'm a hidden post", hidden: true)

      results = Search.execute("hidden post")
      expect(results.posts.count).to eq(0)
    end

    it "does not rely on postgres's proximity opreators" do
      topic.update!(title: "End-to-end something something testing")

      results = Search.execute("end-to-end test")

      expect(results.posts).to eq([post])
    end
  end

  describe "topics" do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    context "with search within topic" do
      def new_post(raw, topic = nil, created_at: nil)
        topic ||= Fabricate(:topic)
        Fabricate(
          :post,
          topic: topic,
          topic_id: topic.id,
          user: topic.user,
          raw: raw,
          created_at: created_at,
        )
      end

      it "works in Chinese" do
        SiteSetting.search_tokenize_chinese = true
        post = new_post("I am not in English 你今天怎麼樣")

        results = Search.execute("你今天", search_context: post.topic)
        expect(results.posts.map(&:id)).to eq([post.id])
      end

      it "works in Japanese" do
        SiteSetting.search_tokenize_japanese = true
        post = new_post("I am not in English 何点になると思いますか")

        results = Search.execute("何点になると思", search_context: post.topic)
        expect(results.posts.map(&:id)).to eq([post.id])
      end

      it "displays multiple results within a topic" do
        topic2 = Fabricate(:topic)

        new_post("this is the other post I am posting", topic2, created_at: 6.minutes.ago)
        new_post("this is my fifth post I am posting", topic2, created_at: 5.minutes.ago)

        post1 = new_post("this is the other post I am posting", topic, created_at: 4.minutes.ago)
        post2 = new_post("this is my first post I am posting", topic, created_at: 3.minutes.ago)
        post3 =
          new_post(
            "this is a real long and complicated bla this is my second post I am Posting birds with more stuff bla bla",
            topic,
            created_at: 2.minutes.ago,
          )
        post4 = new_post("this is my fourth post I am posting", topic, created_at: 1.minute.ago)

        # update posts_count
        topic.reload

        results = Search.execute("posting", search_context: post1.topic)
        expect(results.posts.map(&:id)).to eq([post1.id, post2.id, post3.id, post4.id])

        results = Search.execute("posting l", search_context: post1.topic)
        expect(results.posts.map(&:id)).to eq([post4.id, post3.id, post2.id, post1.id])

        # stop words should work
        results = Search.execute("this", search_context: post1.topic)
        expect(results.posts.length).to eq(4)

        # phrase search works as expected
        results = Search.execute('"fourth post I am posting"', search_context: post1.topic)
        expect(results.posts.length).to eq(1)
      end

      it "works for unlisted topics" do
        topic.update(visible: false)
        _post = new_post("discourse is awesome", topic)
        results = Search.execute("discourse", search_context: topic)
        expect(results.posts.length).to eq(1)
      end
    end

    context "when searching the OP" do
      let!(:post) { Fabricate(:post_with_long_raw_content) }
      let(:result) { Search.execute("hundred", type_filter: "topic") }

      it "returns a result correctly" do
        expect(result.posts.length).to eq(1)
        expect(result.posts[0].id).to eq(post.id)
      end
    end

    context "when searching for quoted title" do
      it "can find quoted title" do
        create_post(raw: "this is the raw body", title: "I am a title yeah")
        result = Search.execute('"a title yeah"')

        expect(result.posts.length).to eq(1)
      end
    end

    context "when searching for a topic by id" do
      let(:result) do
        Search.execute(
          topic.id,
          type_filter: "topic",
          search_for_id: true,
          min_search_term_length: 1,
        )
      end

      it "returns the topic" do
        expect(result.posts.length).to eq(1)
        expect(result.posts.first.id).to eq(post.id)
      end
    end

    context "when searching for a topic by url" do
      it "returns the topic" do
        result = Search.execute(topic.relative_url, search_for_id: true, type_filter: "topic")
        expect(result.posts.length).to eq(1)
        expect(result.posts.first.id).to eq(post.id)
      end

      context "with restrict_to_archetype" do
        let(:personal_message) { Fabricate(:private_message_topic) }
        let!(:p1) { Fabricate(:post, topic: personal_message, post_number: 1) }

        it "restricts result to topics" do
          result =
            Search.execute(
              personal_message.relative_url,
              search_for_id: true,
              type_filter: "topic",
              restrict_to_archetype: Archetype.default,
            )
          expect(result.posts.length).to eq(0)

          result =
            Search.execute(
              topic.relative_url,
              search_for_id: true,
              type_filter: "topic",
              restrict_to_archetype: Archetype.default,
            )
          expect(result.posts.length).to eq(1)
        end

        it "restricts result to messages" do
          result =
            Search.execute(
              topic.relative_url,
              search_for_id: true,
              type_filter: "private_messages",
              guardian: Guardian.new(admin),
              restrict_to_archetype: Archetype.private_message,
            )
          expect(result.posts.length).to eq(0)

          result =
            Search.execute(
              personal_message.relative_url,
              search_for_id: true,
              type_filter: "private_messages",
              guardian: Guardian.new(admin),
              restrict_to_archetype: Archetype.private_message,
            )
          expect(result.posts.length).to eq(1)
        end
      end
    end

    context "with security" do
      def result(current_user)
        Search.execute("hello", guardian: Guardian.new(current_user))
      end

      it "secures results correctly" do
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

  describe "cyrillic topic" do
    let!(:cyrillic_topic) do
      Fabricate(:topic) do
        user
        title { sequence(:title) { |i| "Тестовая запись #{i}" } }
      end
    end

    let!(:post) { Fabricate(:post, topic: cyrillic_topic, user: cyrillic_topic.user) }
    let(:result) { Search.execute("запись") }

    it "finds something when given cyrillic query" do
      expect(result.posts).to contain_exactly(post)
    end
  end

  it "does not tokenize search term" do
    Fabricate(:post, raw: "thing is canned should still be found!")
    expect(Search.execute("canned").posts).to be_present
  end

  describe "categories" do
    let(:category) { Fabricate(:category_with_definition, name: "monkey Category 2") }
    let(:topic) { Fabricate(:topic, category: category) }
    let!(:post) { Fabricate(:post, topic: topic, raw: "snow monkey") }

    let!(:ignored_category) do
      Fabricate(
        :category_with_definition,
        name: "monkey Category 1",
        slug: "test",
        search_priority: Searchable::PRIORITIES[:ignore],
      )
    end

    it "allow searching for multiple categories" do
      category2 = Fabricate(:category, name: "abc")
      topic2 = Fabricate(:topic, category: category2)
      post2 = Fabricate(:post, topic: topic2, raw: "snow monkey")

      category3 = Fabricate(:category, name: "def")
      topic3 = Fabricate(:topic, category: category3)
      post3 = Fabricate(:post, topic: topic3, raw: "snow monkey")

      search = Search.execute("monkey category:abc,def")
      expect(search.posts.map(&:id)).to contain_exactly(post2.id, post3.id)

      search = Search.execute("monkey categories:abc,def")
      expect(search.posts.map(&:id)).to contain_exactly(post2.id, post3.id)

      search = Search.execute("monkey categories:xxxxx,=abc,=def")
      expect(search.posts.map(&:id)).to contain_exactly(post2.id, post3.id)

      search = Search.execute("snow category:abc,#{category.id}")
      expect(search.posts.map(&:id)).to contain_exactly(post.id, post2.id)

      child_category = Fabricate(:category, parent_category: category2)
      child_topic = Fabricate(:topic, category: child_category)
      child_post = Fabricate(:post, topic: child_topic, raw: "snow monkey")

      search = Search.execute("monkey category:zzz,nnn,=abc,mmm")
      expect(search.posts.map(&:id)).to contain_exactly(post2.id)

      search =
        Search.execute(
          "monkey category:0007847874874874874748749398384398439843984938439843948394834984934839483984983498394834983498349834983,zzz,nnn,abc,mmm",
        )
      expect(search.posts.map(&:id)).to contain_exactly(post2.id, child_post.id)
    end

    it "should return the right categories" do
      search = Search.execute("monkey")

      expect(search.categories).to contain_exactly(category, ignored_category)

      expect(search.posts).to eq([category.topic.first_post, post])

      search = Search.execute("monkey #test")

      expect(search.posts).to eq([ignored_category.topic.first_post])
    end

    describe "with child categories" do
      let!(:child_of_ignored_category) do
        Fabricate(
          :category_with_definition,
          name: "monkey Category 3",
          parent_category: ignored_category,
        )
      end

      let!(:post2) do
        Fabricate(
          :post,
          topic: Fabricate(:topic, category: child_of_ignored_category),
          raw: "snow monkey park",
        )
      end

      it "returns the right results" do
        search = Search.execute("monkey")

        expect(search.categories).to contain_exactly(
          category,
          ignored_category,
          child_of_ignored_category,
        )

        expect(search.posts.map(&:id)).to eq(
          [child_of_ignored_category.topic.first_post, category.topic.first_post, post2, post].map(
            &:id
          ),
        )

        search = Search.execute("snow")
        expect(search.posts.map(&:id)).to eq([post2.id, post.id])

        category.set_permissions({})
        category.save!
        search = Search.execute("monkey")

        expect(search.categories).to contain_exactly(ignored_category, child_of_ignored_category)

        expect(search.posts.map(&:id)).to eq(
          [child_of_ignored_category.topic.first_post, post2].map(&:id),
        )
      end
    end

    describe "categories with different priorities" do
      let(:category2) { Fabricate(:category_with_definition) }

      it "should return posts in the right order" do
        raw = "The pure genuine evian"
        post = Fabricate(:post, topic: category.topic, raw: raw)
        post2 = Fabricate(:post, topic: category2.topic, raw: raw)
        post2.topic.update!(bumped_at: 10.seconds.from_now)

        search = Search.execute(raw)

        expect(search.posts.map(&:id)).to eq([post2.id, post.id])

        category.update!(search_priority: Searchable::PRIORITIES[:high])

        search = Search.execute(raw)

        expect(search.posts.map(&:id)).to eq([post.id, post2.id])
      end
    end
  end

  describe "groups" do
    def search(user = Fabricate(:user))
      Search.execute(group.name, guardian: Guardian.new(user))
    end

    let!(:group) { Group[:trust_level_0] }

    it "shows group" do
      expect(search.groups.map(&:name)).to eq([group.name])
    end

    context "with group visibility" do
      let!(:group) { Fabricate(:group) }

      before { group.update!(visibility_level: 3) }

      context "with staff logged in" do
        it "shows group" do
          expect(search(admin).groups.map(&:name)).to eq([group.name])
        end
      end

      context "with non staff logged in" do
        fab!(:user)

        it "shows doesn't show group" do
          expect(search(user).groups.map(&:name)).to eq([])
        end
      end
    end

    context "with registered plugin callbacks" do
      let!(:group) { Fabricate(:group, name: "plugin-special") }

      context "when :search_groups_set_query_callback is registered" do
        it "changes the search results" do
          # initial result (without applying the plugin callback )
          expect(search.groups.map(&:name).include?("plugin-special")).to eq(true)

          DiscoursePluginRegistry.register_search_groups_set_query_callback(
            Proc.new { |query, term, guardian| query.where.not(name: "plugin-special") },
            Plugin::Instance.new,
          )

          # after using the callback we expect the search result to be changed because the
          # query was altered
          expect(search.groups.map(&:name).include?("plugin-special")).to eq(false)

          DiscoursePluginRegistry.reset_register!(:search_groups_set_query_callbacks)
        end
      end
    end
  end

  describe "tags" do
    def search
      Search.execute(tag.name)
    end

    let!(:tag) { Fabricate(:tag) }
    let!(:uppercase_tag) { Fabricate(:tag, name: "HeLlO") }
    let(:tag_group) { Fabricate(:tag_group) }
    let(:category) { Fabricate(:category_with_definition) }

    context "with post searching" do
      before do
        SiteSetting.tagging_enabled = true
        DiscourseTagging.tag_topic_by_names(
          post.topic,
          Guardian.new(Fabricate(:admin, refresh_auto_groups: true)),
          [tag.name, uppercase_tag.name],
        )
        post.topic.save
      end

      let(:post) { Fabricate(:post, raw: "I am special post") }

      it "can find posts with tags" do
        # we got to make this index (it is deferred)
        Jobs::ReindexSearch.new.rebuild_posts

        result = Search.execute(tag.name)
        expect(result.posts.length).to eq(1)

        result = Search.execute("hElLo")
        expect(result.posts.length).to eq(1)

        SiteSetting.tagging_enabled = false

        result = Search.execute(tag.name)
        expect(result.posts.length).to eq(0)
      end

      it "can find posts with tag synonyms" do
        synonym = Fabricate(:tag, name: "synonym", target_tag: tag)
        Jobs::ReindexSearch.new.rebuild_posts
        result = Search.execute(synonym.name)
        expect(result.posts.length).to eq(1)
      end
    end

    context "when tagging is disabled" do
      before { SiteSetting.tagging_enabled = false }

      it "does not include tags" do
        expect(search.tags).to_not be_present
      end
    end

    context "when tagging is enabled" do
      before { SiteSetting.tagging_enabled = true }

      it "returns the tag in the result" do
        expect(search.tags).to eq([tag])
      end

      it "shows staff tags" do
        create_staff_only_tags(["#{tag.name}9"])

        expect(Search.execute(tag.name, guardian: Guardian.new(admin)).tags.map(&:name)).to eq(
          [tag.name, "#{tag.name}9"],
        )
        expect(search.tags.map(&:name)).to eq([tag.name, "#{tag.name}9"])
      end

      it "includes category-restricted tags" do
        category_tag = Fabricate(:tag, name: "#{tag.name}9")
        tag_group.tags = [category_tag]
        category.set_permissions(admins: :full)
        category.allowed_tag_groups = [tag_group.name]
        category.save!

        expect(Search.execute(tag.name, guardian: Guardian.new(admin)).tags).to eq(
          [tag, category_tag],
        )
        expect(search.tags).to eq([tag, category_tag])
      end
    end
  end

  describe "type_filter" do
    let!(:user) { Fabricate(:user, username: "amazing", email: "amazing@amazing.com") }
    let!(:category) { Fabricate(:category_with_definition, name: "amazing category", user: user) }

    context "with user filter" do
      let(:results) { Search.execute("amazing", type_filter: "user") }

      it "returns a user result" do
        expect(results.categories.length).to eq(0)
        expect(results.posts.length).to eq(0)
        expect(results.users.length).to eq(1)
      end
    end

    context "with category filter" do
      let(:results) { Search.execute("amazing", type_filter: "category") }

      it "returns a category result" do
        expect(results.categories.length).to eq(1)
        expect(results.posts.length).to eq(0)
        expect(results.users.length).to eq(0)
      end
    end
  end

  describe "search_context" do
    it "can find a user when using search context" do
      coding_horror = Fabricate(:coding_horror)
      post = Fabricate(:post)

      Fabricate(:post, user: coding_horror)

      result = Search.execute("hello", search_context: post.user)

      result.posts.first.topic_id = post.topic_id
      expect(result.posts.length).to eq(1)
    end

    it "can use category as a search context" do
      category =
        Fabricate(:category_with_definition, search_priority: Searchable::PRIORITIES[:ignore])

      topic = Fabricate(:topic, category: category)
      topic_no_cat = Fabricate(:topic)

      # includes subcategory in search
      subcategory = Fabricate(:category_with_definition, parent_category_id: category.id)
      sub_topic = Fabricate(:topic, category: subcategory)

      post = Fabricate(:post, topic: topic, user: topic.user)
      Fabricate(:post, topic: topic_no_cat, user: topic.user)
      sub_post =
        Fabricate(
          :post,
          raw: "I am saying hello from a subcategory",
          topic: sub_topic,
          user: topic.user,
        )

      search = Search.execute("hello", search_context: category)
      expect(search.posts.map(&:id)).to match_array([post.id, sub_post.id])
      expect(search.posts.length).to eq(2)
    end

    it "can use tag as a search context" do
      tag = Fabricate(:tag, name: "important-stuff")

      topic_no_tag = Fabricate(:topic)
      Fabricate(:topic_tag, tag: tag, topic: topic)

      post = Fabricate(:post, topic: topic, user: topic.user, raw: "This is my hello")
      Fabricate(:post, topic: topic_no_tag, user: topic.user)

      search = Search.execute("hello", search_context: tag)
      expect(search.posts.map(&:id)).to contain_exactly(post.id)
      expect(search.posts.length).to eq(1)
    end
  end

  describe "Japanese search" do
    let!(:topic) { Fabricate(:topic) }
    let!(:post) { Fabricate(:post, topic: topic, raw: "This is some japanese text 日本が大好きです。") }
    let!(:topic_2) { Fabricate(:topic, title: "日本の話題、 more japanese text") }
    let!(:post_2) { Fabricate(:post, topic: topic_2) }

    describe ".prepare_data" do
      subject(:prepared_data) { Search.prepare_data(data) }

      let(:data) { post.raw }

      before { SiteSetting.search_tokenize_japanese = true }

      it "removes punctuations" do
        expect(prepared_data).to eq("This is some japanese text 日本 が 大好き です")
      end

      context "when providing only an URL" do
        let(:data) { "http://localhost/t/-/51" }

        it "does not change it" do
          expect(prepared_data).to eq(data)
        end
      end

      context "when providing only a path" do
        let(:data) { "/t/-/51" }

        it "does not change it" do
          expect(prepared_data).to eq(data)
        end
      end

      context "when providing only an ID" do
        let(:data) { "51" }

        it "does not change it" do
          expect(prepared_data).to eq(data)
        end
      end
    end

    describe ".execute" do
      before do
        @old_default = SiteSetting.defaults.get(:min_search_term_length)
        SiteSetting.defaults.set_regardless_of_locale(:min_search_term_length, 1)
        SiteSetting.refresh!
      end

      after do
        SiteSetting.defaults.set_regardless_of_locale(:min_search_term_length, @old_default)
        SiteSetting.refresh!
      end

      context "when tokenization is forced" do
        before { SiteSetting.search_tokenize_japanese = true }

        it "finds posts containing Japanese text" do
          expect(Search.execute("日本").posts.map(&:id)).to eq([post_2.id, post.id])
          expect(Search.execute("日").posts.map(&:id)).to eq([post_2.id, post.id])
        end
      end

      context "when default locale is set to Japanese" do
        before { SiteSetting.default_locale = "ja" }

        it "find posts containing search term" do
          expect(Search.execute("日本").posts.map(&:id)).to eq([post_2.id, post.id])
          expect(Search.execute("日").posts.map(&:id)).to eq([post_2.id, post.id])
        end

        it "does not include superfluous spaces in blurbs" do
          post.update!(
            raw: "場サアマネ織企ういかせ竹域ヱイマ穂基ホ神3予読ずねいぱ松査ス禁多サウ提懸イふ引小43改こょドめ。深とつぐ主思料農ぞかル者杯検める活分えほづぼ白犠",
          )

          results = Search.execute("ういかせ竹域", type_filter: "topic")

          expect(results.posts.length).to eq(1)
          expect(results.blurb(results.posts.first)).to include("ういかせ竹域")
        end

        context "when searching for a topic in particular" do
          subject(:results) do
            described_class.execute(
              term,
              guardian: Discourse.system_user.guardian,
              type_filter: "topic",
              search_for_id: true,
            )
          end

          context "when searching by topic ID" do
            let(:term) { topic.id }

            it "finds the proper post" do
              expect(results.posts.first).to have_attributes(topic: topic, post_number: 1)
            end
          end

          context "when searching by topic URL" do
            let(:term) { "http://#{Discourse.current_hostname}/t/-/#{topic.id}" }

            it "finds the proper post" do
              expect(results.posts.first).to have_attributes(topic: topic, post_number: 1)
            end
          end

          context "when searching by topic path" do
            let(:term) { "/t/-/#{topic.id}" }

            it "finds the proper post" do
              expect(results.posts.first).to have_attributes(topic: topic, post_number: 1)
            end
          end
        end
      end
    end
  end

  describe "Chinese search" do
    let(:sentence) { "Discourse is a software company 中国的基础设施网络正在组装。" }
    let(:sentence_t) { "Discourse is a software company 太平山森林遊樂區。" }

    it "splits English / Chinese and filter out Chinese stop words" do
      SiteSetting.default_locale = "zh_CN"
      data = Search.prepare_data(sentence)
      expect(data).to eq("Discourse is a software company 中国 基础设施 网络 正在 组装")
    end

    it "splits for indexing and filter out stop words" do
      SiteSetting.default_locale = "zh_CN"
      data = Search.prepare_data(sentence, :index)
      expect(data).to eq("Discourse is a software company 中国 基础设施 网络 正在 组装")
    end

    it "splits English / Traditional Chinese and filter out stop words" do
      SiteSetting.default_locale = "zh_TW"
      data = Search.prepare_data(sentence_t)
      expect(data).to eq("Discourse is a software company 太平山 森林 遊樂區")
    end

    it "does not split strings beginning with numeric chars into different segments" do
      SiteSetting.default_locale = "zh_TW"
      data = Search.prepare_data("#{sentence} 123abc")
      expect(data).to eq("Discourse is a software company 中国 基础设施 网络 正在 组装 123abc")
    end

    it "finds chinese topic based on title" do
      SiteSetting.default_locale = "zh_TW"
      SiteSetting.min_search_term_length = 1

      topic = Fabricate(:topic, title: "My Title Discourse社區指南")
      post = Fabricate(:post, topic: topic)

      expect(Search.execute("社區指南").posts.first.id).to eq(post.id)
      expect(Search.execute("指南").posts.first.id).to eq(post.id)
    end

    it "finds chinese topic based on title if tokenization is forced" do
      begin
        SiteSetting.search_tokenize_chinese = true
        default_min_search_term_length = SiteSetting.defaults.get(:min_search_term_length)
        SiteSetting.defaults.set_regardless_of_locale(:min_search_term_length, 1)
        SiteSetting.refresh!

        topic = Fabricate(:topic, title: "My Title Discourse社區指南")
        post = Fabricate(:post, topic: topic)

        expect(Search.execute("社區指南").posts.first.id).to eq(post.id)
        expect(Search.execute("指南").posts.first.id).to eq(post.id)
      ensure
        if default_min_search_term_length
          SiteSetting.defaults.set_regardless_of_locale(
            :min_search_term_length,
            default_min_search_term_length,
          )
          SiteSetting.refresh!
        end
      end
    end
  end

  describe "Advanced search" do
    describe "bookmarks" do
      fab!(:user)
      let!(:bookmark_post1) { Fabricate(:post, raw: "boom this is a bookmarked post") }
      let!(:bookmark_post2) { Fabricate(:post, raw: "wow some other cool thing") }

      def search_with_bookmarks
        Search.execute("boom in:bookmarks", guardian: Guardian.new(user))
      end

      it "can filter by posts in the user's bookmarks" do
        expect(search_with_bookmarks.posts.map(&:id)).to eq([])
        Fabricate(:bookmark, user: user, bookmarkable: bookmark_post1)
        expect(search_with_bookmarks.posts.map(&:id)).to match_array([bookmark_post1.id])
      end
    end

    it "supports pinned" do
      Fabricate(:post, raw: "hi this is a test 123 123", topic: topic)
      _post = Fabricate(:post, raw: "boom boom shake the room", topic: topic)

      topic.update_pinned(true)

      expect(Search.execute("boom in:pinned").posts.length).to eq(1)
      expect(Search.execute("boom IN:PINNED").posts.length).to eq(1)
    end

    it "supports wiki" do
      topic_2 = Fabricate(:topic)
      post = Fabricate(:post, raw: "this is a test 248", wiki: true, topic: topic)
      Fabricate(:post, raw: "this is a test 248", wiki: false, topic: topic_2)

      expect(Search.execute("test 248").posts.length).to eq(2)
      expect(Search.execute("test 248 in:wiki").posts.first).to eq(post)
      expect(Search.execute("test 248 IN:WIKI").posts.first).to eq(post)
    end

    it "supports searching for posts that the user has seen/unseen" do
      topic_2 = Fabricate(:topic)
      post = Fabricate(:post, raw: "logan is longan", topic: topic)
      post_2 = Fabricate(:post, raw: "longan is logan", topic: topic_2)

      [post.user, topic.user].each do |user|
        PostTiming.create!(post_number: post.post_number, topic: topic, user: user, msecs: 1)
      end

      expect(post.seen?(post.user)).to eq(true)

      expect(Search.execute("longan").posts.sort).to eq([post, post_2])

      expect(Search.execute("longan in:seen", guardian: Guardian.new(post.user)).posts).to eq(
        [post],
      )

      expect(Search.execute("longan IN:SEEN", guardian: Guardian.new(post.user)).posts).to eq(
        [post],
      )

      expect(Search.execute("longan in:seen").posts.sort).to eq([post, post_2])

      expect(Search.execute("longan in:seen", guardian: Guardian.new(post_2.user)).posts).to eq([])

      expect(Search.execute("longan", guardian: Guardian.new(post_2.user)).posts.sort).to eq(
        [post, post_2],
      )

      expect(
        Search.execute("longan in:unseen", guardian: Guardian.new(post_2.user)).posts.sort,
      ).to eq([post, post_2])

      expect(Search.execute("longan in:unseen", guardian: Guardian.new(post.user)).posts).to eq(
        [post_2],
      )

      expect(Search.execute("longan IN:UNSEEN", guardian: Guardian.new(post.user)).posts).to eq(
        [post_2],
      )
    end

    it "supports before and after filters" do
      time = Time.zone.parse("2001-05-20 2:55")
      freeze_time(time)

      post_1 = Fabricate(:post, raw: "hi this is a test 123 123", created_at: time.months_ago(2))
      post_2 = Fabricate(:post, raw: "boom boom shake the room test")

      expect(Search.execute("test before:1").posts).to contain_exactly(post_1)
      expect(Search.execute("test before:2001-04-20").posts).to contain_exactly(post_1)
      expect(Search.execute("test before:2001").posts).to eq([])
      expect(Search.execute("test after:2001").posts).to contain_exactly(post_1, post_2)
      expect(Search.execute("test before:monday").posts).to contain_exactly(post_1)
      expect(Search.execute("test after:jan").posts).to contain_exactly(post_1, post_2)
    end

    it "supports in:first, user:, @username" do
      post_1 = Fabricate(:post, raw: "hi this is a test 123 123", topic: topic)
      post_2 = Fabricate(:post, raw: "boom boom shake the room test", topic: topic)

      expect(Search.execute("test in:first").posts).to contain_exactly(post_1)
      expect(Search.execute("test IN:FIRST").posts).to contain_exactly(post_1)

      expect(Search.execute("boom").posts).to contain_exactly(post_2)

      expect(Search.execute("boom in:first").posts).to eq([])
      expect(Search.execute("boom f").posts).to eq([])

      expect(Search.execute("123 in:first").posts).to contain_exactly(post_1)
      expect(Search.execute("123 f").posts).to contain_exactly(post_1)

      expect(Search.execute("user:nobody").posts).to eq([])
      expect(Search.execute("user:#{post_1.user.username}").posts).to contain_exactly(post_1)
      expect(Search.execute("user:#{post_1.user_id}").posts).to contain_exactly(post_1)

      expect(Search.execute("@#{post_1.user.username}").posts).to contain_exactly(post_1)

      SiteSetting.unicode_usernames = true
      unicode_user = Fabricate(:unicode_user)
      post_3 = Fabricate(:post, user: unicode_user, raw: "post by a unicode user", topic: topic)

      expect(Search.execute("@#{post_3.user.username}").posts).to contain_exactly(post_3)
    end

    context "when searching for posts made by users of a group" do
      fab!(:topic) { Fabricate(:topic, created_at: 3.months.ago) }
      fab!(:user)
      fab!(:user_2) { Fabricate(:user) }
      fab!(:user_3) { Fabricate(:user) }
      fab!(:group) { Fabricate(:group, name: "Like_a_Boss").tap { |g| g.add(user) } }
      fab!(:group_2) { Fabricate(:group).tap { |g| g.add(user_2) } }
      let!(:post) { Fabricate(:post, raw: "hi this is a test 123 123", topic: topic, user: user) }
      let!(:post_2) { Fabricate(:post, user: user_2) }

      it "should not return any posts if group does not exist" do
        group.update!(
          visibility_level: Group.visibility_levels[:public],
          members_visibility_level: Group.visibility_levels[:public],
        )

        expect(Search.execute("group:99999").posts).to eq([])
      end

      it "should return the right posts for a public group" do
        group.update!(
          visibility_level: Group.visibility_levels[:public],
          members_visibility_level: Group.visibility_levels[:public],
        )

        expect(Search.execute("group:like_a_boss").posts).to contain_exactly(post)
        expect(Search.execute("group:#{group.id}").posts).to contain_exactly(post)
      end

      it "should return the right posts for a public group with members' visibility restricted to logged on users" do
        group.update!(
          visibility_level: Group.visibility_levels[:public],
          members_visibility_level: Group.visibility_levels[:logged_on_users],
        )

        expect(Search.execute("group:#{group.id}").posts).to eq([])
        expect(
          Search.execute("group:#{group.id}", guardian: Guardian.new(user_3)).posts,
        ).to contain_exactly(post)
      end

      it "should return the right posts for a group with visibility restricted to logged on users with members' visibility restricted to members" do
        group.update!(
          visibility_level: Group.visibility_levels[:logged_on_users],
          members_visibility_level: Group.visibility_levels[:members],
        )

        expect(Search.execute("group:#{group.id}").posts).to eq([])
        expect(Search.execute("group:#{group.id}", guardian: Guardian.new(user_3)).posts).to eq([])
        expect(
          Search.execute("group:#{group.id}", guardian: Guardian.new(user)).posts,
        ).to contain_exactly(post)
      end

      context "with registered plugin callbacks" do
        context "when :search_groups_set_query_callback is registered" do
          it "changes the search results" do
            group.update!(
              visibility_level: Group.visibility_levels[:public],
              members_visibility_level: Group.visibility_levels[:public],
            )

            # initial result (without applying the plugin callback )
            expect(Search.execute("group:like_a_boss").posts).to contain_exactly(post)

            DiscoursePluginRegistry.register_search_groups_set_query_callback(
              Proc.new { |query, term, guardian| query.where.not(name: "Like_a_Boss") },
              Plugin::Instance.new,
            )

            # after using the callback we expect the search result to be changed because the
            # query was altered
            expect(Search.execute("group:like_a_boss").posts).to be_blank

            DiscoursePluginRegistry.reset_register!(:search_groups_set_query_callbacks)
          end
        end
      end
    end

    it "supports badge" do
      topic = Fabricate(:topic, created_at: 3.months.ago)
      post = Fabricate(:post, raw: "hi this is a test 123 123", topic: topic)

      badge = Badge.create!(name: "Like a Boss", badge_type_id: 1)
      UserBadge.create!(
        user_id: post.user_id,
        badge_id: badge.id,
        granted_at: 1.minute.ago,
        granted_by_id: -1,
      )

      expect(Search.execute('badge:"like a boss"').posts.length).to eq(1)
      expect(Search.execute('BADGE:"LIKE A BOSS"').posts.length).to eq(1)
      expect(Search.execute('badge:"test"').posts.length).to eq(0)
    end

    it "can match exact phrases" do
      post =
        Fabricate(
          :post,
          raw:
            "this is a test post with 'a URL https://some.site.com/search?q=test.test.test some random text I have to add",
        )
      post2 = Fabricate(:post, raw: "test URL post with")

      expect(Search.execute("test post URL l").posts).to eq([post2, post])
      expect(Search.execute(%{"test post with 'a URL"}).posts).to eq([post])
      expect(Search.execute(%{"https://some.site.com/search?q=test.test.test"}).posts).to eq([post])
      expect(
        Search.execute(%{" with 'a URL https://some.site.com/search?q=test.test.test"}).posts,
      ).to eq([post])
    end

    it "can search numbers correctly, and match exact phrases" do
      post = Fabricate(:post, raw: "3.0 eta is in 2 days horrah")
      post2 = Fabricate(:post, raw: "3.0 is eta in 2 days horrah")

      expect(Search.execute("3.0 eta").posts).to eq([post, post2])
      expect(Search.execute("'3.0 eta'").posts).to eq([post, post2])
      expect(Search.execute("\"3.0 eta\"").posts).to contain_exactly(post)
      expect(Search.execute('"3.0, eta is"').posts).to eq([])
    end

    it "can find by status" do
      public_category = Fabricate(:category, read_restricted: false)
      post = Fabricate(:post, raw: "hi this is a test 123 123")
      topic = post.topic
      topic.update(category: public_category)

      private_category = Fabricate(:category, read_restricted: true)
      post2 = Fabricate(:post, raw: "hi this is another test 123 123")
      second_topic = post2.topic
      second_topic.update(category: private_category)

      _post3 = Fabricate(:post, raw: "another test!", user: topic.user, topic: second_topic)

      expect(Search.execute("test status:public").posts.length).to eq(1)
      expect(Search.execute("test status:closed").posts.length).to eq(0)
      expect(Search.execute("test status:open").posts.length).to eq(1)
      expect(Search.execute("test STATUS:OPEN").posts.length).to eq(1)
      expect(Search.execute("test posts_count:1").posts.length).to eq(1)
      expect(Search.execute("test min_post_count:1").posts.length).to eq(1)
      expect(Search.execute("test min_posts:1").posts.length).to eq(1)
      expect(Search.execute("test max_posts:2").posts.length).to eq(1)

      topic.update(closed: true)
      second_topic.update(category: public_category)

      expect(Search.execute("test status:public").posts.length).to eq(2)
      expect(Search.execute("test status:closed").posts.length).to eq(1)
      expect(Search.execute("status:closed").posts.length).to eq(1)
      expect(Search.execute("test status:open").posts.length).to eq(1)

      topic.update(archived: true, closed: false)
      second_topic.update(closed: true)

      expect(Search.execute("test status:archived").posts.length).to eq(1)
      expect(Search.execute("test status:open").posts.length).to eq(0)

      expect(Search.execute("test status:noreplies").posts.length).to eq(1)

      expect(
        Search.execute("test in:likes", guardian: Guardian.new(topic.user)).posts.length,
      ).to eq(0)

      expect(
        Search.execute("test in:posted", guardian: Guardian.new(topic.user)).posts.length,
      ).to eq(2)
      expect(
        Search.execute("test In:PoStEd", guardian: Guardian.new(topic.user)).posts.length,
      ).to eq(2)

      in_created = Search.execute("test in:created", guardian: Guardian.new(topic.user)).posts
      created_by_user =
        Search.execute(
          "test created:@#{topic.user.username}",
          guardian: Guardian.new(topic.user),
        ).posts
      expect(in_created.length).to eq(1)
      expect(created_by_user.length).to eq(1)
      expect(in_created).to eq(created_by_user)

      expect(
        Search
          .execute(
            "test created:@#{second_topic.user.username}",
            guardian: Guardian.new(topic.user),
          )
          .posts
          .length,
      ).to eq(1)

      new_user = Fabricate(:user)
      expect(
        Search
          .execute("test created:@#{new_user.username}", guardian: Guardian.new(topic.user))
          .posts
          .length,
      ).to eq(0)

      TopicUser.change(
        topic.user.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      expect(
        Search.execute("test in:watching", guardian: Guardian.new(topic.user)).posts.length,
      ).to eq(0)
      expect(
        Search.execute("test in:tracking", guardian: Guardian.new(topic.user)).posts.length,
      ).to eq(1)

      another_user = Fabricate(:user, username: "AnotherUser")
      post4 = Fabricate(:post, raw: "test by uppercase username", user: another_user)
      topic4 = post4.topic
      topic4.update(category: public_category)

      expect(
        Search
          .execute("test created:@#{another_user.username}", guardian: Guardian.new())
          .posts
          .length,
      ).to eq(1)
    end

    it "can find posts with images" do
      user = Fabricate(:user, refresh_auto_groups: true)
      post_uploaded = Fabricate(:post_with_uploaded_image, user: user)
      Fabricate(:post, user: user)

      CookedPostProcessor.new(post_uploaded).update_post_image

      expect(Search.execute("with:images").posts.map(&:id)).to contain_exactly(post_uploaded.id)
    end

    it "defaults to search_default_sort_order when no order is provided" do
      topic1 = Fabricate(:topic, title: "I do not like that Sam I am", created_at: 1.minute.ago)
      post1 = Fabricate(:post, topic: topic1, created_at: 10.minutes.ago)
      post2 =
        Fabricate(
          :post,
          raw: "that Sam I am, that Sam I am",
          created_at: 5.minutes.ago,
          topic: Fabricate(:topic, created_at: 1.hour.ago),
        )

      SiteSetting.search_default_sort_order = SearchSortOrderSiteSetting.value_from_id(:latest)

      expect(Search.execute("sam").posts.map(&:id)).to eq([post2.id, post1.id])
      expect(Search.execute("sam ORDER:LATEST").posts.map(&:id)).to eq([post2.id, post1.id])

      SiteSetting.search_default_sort_order =
        SearchSortOrderSiteSetting.value_from_id(:latest_topic)

      expect(Search.execute("sam").posts.map(&:id)).to eq([post1.id, post2.id])
      expect(Search.execute("sam ORDER:LATEST_TOPIC").posts.map(&:id)).to eq([post1.id, post2.id])
    end

    it "can order by latest" do
      topic1 = Fabricate(:topic, title: "I do not like that Sam I am")
      post1 = Fabricate(:post, topic: topic1, created_at: 10.minutes.ago)
      post2 = Fabricate(:post, raw: "that Sam I am, that Sam I am", created_at: 5.minutes.ago)

      expect(Search.execute("sam").posts.map(&:id)).to eq([post1.id, post2.id])
      expect(Search.execute("sam ORDER:LATEST").posts.map(&:id)).to eq([post2.id, post1.id])
      expect(Search.execute("sam l").posts.map(&:id)).to eq([post2.id, post1.id])
      expect(Search.execute("l sam").posts.map(&:id)).to eq([post2.id, post1.id])
    end

    it "can order by oldest" do
      topic1 = Fabricate(:topic, title: "I do not like that Sam I am")
      post1 = Fabricate(:post, topic: topic1, raw: "sam is a sam sam sam") # score higher

      topic2 = Fabricate(:topic, title: "I do not like that Sam I am 2", created_at: 5.minutes.ago)
      post2 = Fabricate(:post, topic: topic2, created_at: 5.minutes.ago)

      expect(Search.execute("sam").posts.map(&:id)).to eq([post1.id, post2.id])
      expect(Search.execute("sam ORDER:oldest").posts.map(&:id)).to eq([post2.id, post1.id])
    end

    it "can order by topic creation" do
      today = Date.today
      yesterday = 1.day.ago
      two_days_ago = 2.days.ago
      category = Fabricate(:category_with_definition)

      old_topic =
        Fabricate(
          :topic,
          title: "First Topic, testing the created_at sort",
          created_at: two_days_ago,
          category: category,
        )

      latest_topic =
        Fabricate(
          :topic,
          title: "Second Topic, testing the created_at sort",
          created_at: yesterday,
          category: category,
        )

      old_relevant_topic_post =
        Fabricate(:post, topic: old_topic, created_at: yesterday, raw: "Relevant Relevant Topic")

      latest_irrelevant_topic_post =
        Fabricate(:post, topic: latest_topic, created_at: today, raw: "Not Relevant")

      # Expecting the default results
      expect(Search.execute("Topic").posts.map(&:id)).to eq(
        [old_relevant_topic_post.id, latest_irrelevant_topic_post.id, category.topic.first_post.id],
      )

      # Expecting the ordered by topic creation results
      expect(Search.execute("Topic order:latest_topic").posts.map(&:id)).to eq(
        [category.topic.first_post.id, latest_irrelevant_topic_post.id, old_relevant_topic_post.id],
      )

      # push weight to the front to ensure test is correct and is not just a coincidence
      latest_irrelevant_topic_post.update!(raw: "Topic Topic Topic")

      expect(Search.execute("Topic order:oldest_topic").posts.map(&:id)).to eq(
        [old_relevant_topic_post.id, latest_irrelevant_topic_post.id, category.topic.first_post.id],
      )
    end

    it "can order by topic views" do
      topic = Fabricate(:topic, views: 1)
      topic2 = Fabricate(:topic, views: 2)
      post = Fabricate(:post, raw: "Topic", topic: topic)
      post2 = Fabricate(:post, raw: "Topic", topic: topic2)

      expect(Search.execute("Topic order:views").posts.map(&:id)).to eq([post2.id, post.id])
    end

    it "can filter by topic views" do
      topic = Fabricate(:topic, views: 100)
      topic2 = Fabricate(:topic, views: 200)
      post = Fabricate(:post, raw: "Topic", topic: topic)
      post2 = Fabricate(:post, raw: "Topic", topic: topic2)

      expect(Search.execute("Topic min_views:150").posts.map(&:id)).to eq([post2.id])
      expect(Search.execute("Topic max_views:150").posts.map(&:id)).to eq([post.id])
    end

    it "can order by likes" do
      raw = "Foo bar lorem ipsum"
      topic = Fabricate(:topic)
      post1 = Fabricate(:post, topic:, raw:, like_count: 1)
      post2 = Fabricate(:post, topic:, raw:, like_count: 2)
      post3 = Fabricate(:post, topic:, raw:, like_count: 3)

      expect(Search.execute("topic:#{topic.id} bar order:likes").posts.map(&:id)).to eq(
        [post3, post2, post1].map(&:id),
      )
    end

    it "can search for terms with dots" do
      post = Fabricate(:post, raw: "Will.2000 Will.Bob.Bill...")
      expect(Search.execute("bill").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("bob").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("2000").posts.map(&:id)).to eq([post.id])
    end

    it "can search URLS correctly" do
      post = Fabricate(:post, raw: "i like http://wb.camra.org.uk/latest#test so yay")

      expect(Search.execute("http://wb.camra.org.uk/latest#test").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("camra").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("http://wb").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("wb.camra").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("wb.camra.org").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("org.uk").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("camra.org.uk").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("wb.camra.org.uk").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("wb.camra.org.uk/latest").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("/latest#test").posts.map(&:id)).to eq([post.id])
    end

    it "supports category slug and tags" do
      # main category
      category = Fabricate(:category_with_definition, name: "category 24", slug: "cateGory-24")
      topic = Fabricate(:topic, created_at: 3.months.ago, category: category)
      post = Fabricate(:post, raw: "Sams first post", topic: topic)

      expect(Search.execute("sams post #categoRy-24").posts.length).to eq(1)
      expect(Search.execute("sams post category:#{category.id}").posts.length).to eq(1)
      expect(Search.execute("sams post #categoRy-25").posts.length).to eq(0)

      sub_category =
        Fabricate(
          :category_with_definition,
          name: "sub category",
          slug: "sub-category",
          parent_category_id: category.id,
        )
      second_topic = Fabricate(:topic, created_at: 3.months.ago, category: sub_category)
      Fabricate(:post, raw: "sams second post", topic: second_topic)

      expect(Search.execute("sams post category:categoRY-24").posts.length).to eq(2)
      expect(Search.execute("sams post category:=cAtegory-24").posts.length).to eq(1)

      expect(Search.execute("sams post #category-24").posts.length).to eq(2)
      expect(Search.execute("sams post #=category-24").posts.length).to eq(1)
      expect(Search.execute("sams post #sub-category").posts.length).to eq(1)

      expect(Search.execute("sams post #categoRY-24:SUB-category").posts.length).to eq(1)

      # tags
      topic.tags = [
        Fabricate(:tag, name: "alpha"),
        Fabricate(:tag, name: "привет"),
        Fabricate(:tag, name: "HeLlO"),
      ]
      expect(Search.execute("this is a test #alpha").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("this is a test #привет").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("this is a test #hElLo").posts.map(&:id)).to eq([post.id])
      expect(Search.execute("this is a test #beta").posts.size).to eq(0)
    end

    it "supports sub-sub category slugs" do
      SiteSetting.max_category_nesting = 3

      category = Fabricate(:category, name: "top", slug: "top")
      sub = Fabricate(:category, name: "middle", slug: "middle", parent_category_id: category.id)
      leaf = Fabricate(:category, name: "leaf", slug: "leaf", parent_category_id: sub.id)

      topic = Fabricate(:topic, created_at: 3.months.ago, category: leaf)
      _post = Fabricate(:post, raw: "Sams first post", topic: topic)

      expect(Search.execute("#Middle:leaf first post").posts.size).to eq(1)
    end

    it "correctly handles #symbol when no tag or category match" do
      Fabricate(:post, raw: "testing #1 #9998")
      results = Search.new("testing #1").execute
      expect(results.posts.length).to eq(1)

      results = Search.new("#9998").execute
      expect(results.posts.length).to eq(1)

      results = Search.new("#nonexistent").execute
      expect(results.posts.length).to eq(0)

      results = Search.new("xxx #:").execute
      expect(results.posts.length).to eq(0)
    end

    context "with tags" do
      fab!(:tag1) { Fabricate(:tag, name: "lunch") }
      fab!(:tag2) { Fabricate(:tag, name: "eggs") }
      fab!(:tag3) { Fabricate(:tag, name: "sandwiches") }

      fab!(:tag_group) do
        group = TagGroup.create!(name: "mid day")
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

      it "can find posts by tag group" do
        expect(Search.execute("#mid-day").posts.map(&:id)).to eq([post5, post4, post3].map(&:id))
      end

      it "can find posts with tag" do
        post4 =
          Fabricate(:post, topic: topic3, raw: "It probably doesn't help that they're green...")

        expect(Search.execute("green tags:eggs").posts.map(&:id)).to eq([post4.id])
        expect(Search.execute("tags:plants").posts.size).to eq(0)
      end

      it "can find posts with non-latin tag" do
        topic.tags = [Fabricate(:tag, name: "さようなら")]
        post = Fabricate(:post, raw: "Testing post", topic: topic)

        expect(Search.execute("tags:さようなら").posts.map(&:id)).to eq([post.id])
      end

      it "can find posts with thai tag" do
        topic.tags = [Fabricate(:tag, name: "เรซิ่น")]
        post = Fabricate(:post, raw: "Testing post", topic: topic)

        expect(Search.execute("tags:เรซิ่น").posts.map(&:id)).to eq([post.id])
      end

      it "can find posts with any tag from multiple tags" do
        expect(Search.execute("tags:eggs,lunch").posts.map(&:id).sort).to eq(
          [post1.id, post2.id, post3.id, post4.id, post5.id].sort,
        )
      end

      it "can find posts which contains all provided tags" do
        expect(Search.execute("tags:lunch+eggs+sandwiches").posts.map(&:id)).to eq([post4.id].sort)
        expect(Search.execute("tags:eggs+lunch+sandwiches").posts.map(&:id)).to eq([post4.id].sort)
      end

      it "can find posts which contains provided tags and does not contain selected ones" do
        expect(Search.execute("tags:eggs -tags:lunch").posts.map(&:id)).to eq(
          [post5, post2, post1].map(&:id),
        )

        expect(Search.execute("tags:eggs -tags:lunch+sandwiches").posts.map(&:id)).to eq(
          [post5, post3, post2, post1].map(&:id),
        )

        expect(Search.execute("tags:eggs -tags:lunch,sandwiches").posts.map(&:id)).to eq(
          [post2, post1].map(&:id),
        )
      end

      it "orders posts correctly when combining tags with categories or terms" do
        cat1 = Fabricate(:category_with_definition, name: "food")
        topic6 = Fabricate(:topic, tags: [tag1, tag2], category: cat1)
        topic7 = Fabricate(:topic, tags: [tag1, tag2, tag3], category: cat1)
        post7 =
          Fabricate(
            :post,
            topic: topic6,
            raw: "Wakey, wakey, eggs and bakey.",
            like_count: 5,
            created_at: 2.minutes.ago,
          )
        post8 =
          Fabricate(
            :post,
            topic: topic7,
            raw: "Bakey, bakey, eggs to makey.",
            like_count: 2,
            created_at: 1.minute.ago,
          )

        expect(Search.execute("bakey tags:lunch order:latest").posts.map(&:id)).to eq(
          [post8.id, post7.id],
        )

        expect(Search.execute("#food tags:lunch order:latest").posts.map(&:id)).to eq(
          [post8.id, post7.id],
        )

        expect(Search.execute("#food tags:lunch order:likes").posts.map(&:id)).to eq(
          [post7.id, post8.id],
        )
      end
    end

    it "can find posts which contains filetypes" do
      post1 = Fabricate(:post, raw: "http://example.com/image.png")

      post2 =
        Fabricate(
          :post,
          raw:
            "Discourse logo\n" \
              "http://example.com/logo.png\n" \
              "http://example.com/vector_image.svg",
        )

      post_with_upload = Fabricate(:post, uploads: [Fabricate(:upload)])
      Fabricate(:post)

      TopicLink.extract_from(post1)
      TopicLink.extract_from(post2)

      expect(Search.execute("filetype:svg").posts).to eq([post2])

      expect(Search.execute("filetype:png").posts.map(&:id)).to eq(
        [post_with_upload, post2, post1].map(&:id),
      )

      expect(Search.execute("logo filetype:png").posts).to eq([post2])
    end
  end

  describe "#ts_query" do
    it "can parse complex strings using ts_query helper" do
      str = +" grigio:babel deprecated? "
      str << "page page on Atmosphere](https://atmospherejs.com/grigio/babel)xxx: aaa.js:222 aaa'\"bbb"

      ts_query = Search.ts_query(term: str, ts_config: "simple")
      expect { DB.exec(+"SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error

      ts_query = Search.ts_query(term: "foo.bar/'&baz", ts_config: "simple")
      expect { DB.exec(+"SELECT to_tsvector('bbb') @@ " << ts_query) }.to_not raise_error
      expect(ts_query).to include("baz")
    end

    it "escapes the term correctly" do
      expect(Search.ts_query(term: 'Title with trailing backslash\\')).to eq(
        "REGEXP_REPLACE(TO_TSQUERY('english', '''Title with trailing backslash\\\\\\\\'':*')::text, '<->|<\\d+>', '&', 'g')::tsquery",
      )

      expect(Search.ts_query(term: "Title with trailing quote'")).to eq(
        "REGEXP_REPLACE(TO_TSQUERY('english', '''Title with trailing quote'''''':*')::text, '<->|<\\d+>', '&', 'g')::tsquery",
      )
    end

    it "remaps postgres's proximity operators '<->' and its `<N>` variant" do
      expect(
        DB.query_single("SELECT #{Search.ts_query(term: "end-to-end")}::text"),
      ).to contain_exactly("'end-to-end':* & 'end':* & 'end':*")
    end
  end

  describe "#word_to_date" do
    it "parses relative dates correctly" do
      time = Time.zone.parse("2001-02-20 2:55")
      freeze_time(time)

      expect(Search.word_to_date("yesterday")).to eq(time.beginning_of_day.yesterday)
      expect(Search.word_to_date("suNday")).to eq(Time.zone.parse("2001-02-18"))
      expect(Search.word_to_date("thursday")).to eq(Time.zone.parse("2001-02-15"))
      expect(Search.word_to_date("deCember")).to eq(Time.zone.parse("2000-12-01"))
      expect(Search.word_to_date("deC")).to eq(Time.zone.parse("2000-12-01"))
      expect(Search.word_to_date("january")).to eq(Time.zone.parse("2001-01-01"))
      expect(Search.word_to_date("jan")).to eq(Time.zone.parse("2001-01-01"))

      expect(Search.word_to_date("100")).to eq(time.beginning_of_day.days_ago(100))

      expect(Search.word_to_date("invalid")).to eq(nil)
    end

    it "parses absolute dates correctly" do
      expect(Search.word_to_date("2001-1-20")).to eq(Time.zone.parse("2001-01-20"))
      expect(Search.word_to_date("2030-10-2")).to eq(Time.zone.parse("2030-10-02"))
      expect(Search.word_to_date("2030-10")).to eq(Time.zone.parse("2030-10-01"))
      expect(Search.word_to_date("2030")).to eq(Time.zone.parse("2030-01-01"))
      expect(Search.word_to_date("2030-01-32")).to eq(nil)
      expect(Search.word_to_date("10000")).to eq(nil)
    end
  end

  describe "#min_post_id" do
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

  describe "search_log_id" do
    it "returns an id when the search succeeds" do
      s = Search.new("indiana jones", search_type: :header, ip_address: "127.0.0.1")
      results = s.execute
      expect(results.search_log_id).to be_present
    end

    it "does not log search if search_type is not present" do
      s = Search.new("foo bar", ip_address: "127.0.0.1")
      results = s.execute
      expect(results.search_log_id).not_to be_present
    end
  end

  describe "in:title" do
    it "allows for search in title" do
      topic = Fabricate(:topic, title: "I am testing a title search")
      _post2 = Fabricate(:post, topic: topic, raw: "this is the second post", post_number: 2)
      post = Fabricate(:post, topic: topic, raw: "this is the first post", post_number: 1)

      results = Search.execute("title in:title")
      expect(results.posts.map(&:id)).to eq([post.id])

      results = Search.execute("title iN:tItLe")
      expect(results.posts.map(&:id)).to eq([post.id])

      results = Search.execute("first in:title")
      expect(results.posts).to eq([])
    end

    it "works irrespective of the order" do
      topic = Fabricate(:topic, title: "A topic about Discourse")
      Fabricate(:post, topic: topic, raw: "This is another post")
      topic2 = Fabricate(:topic, title: "This is another topic")
      Fabricate(:post, topic: topic2, raw: "Discourse is awesome")

      results = Search.execute("Discourse in:title status:open")
      expect(results.posts.length).to eq(1)

      results = Search.execute("in:title status:open Discourse")
      expect(results.posts.length).to eq(1)
    end
  end

  describe "include:invisible / include:unlisted" do
    it "allows including invisible topics in the results for users that can see unlisted topics" do
      topic = Fabricate(:topic, title: "I am testing a search", visible: false)
      post = Fabricate(:post, topic: topic, raw: "this is the first post", post_number: 1)

      results = Search.execute("testing include:invisible", guardian: Guardian.new(admin))
      expect(results.posts.map(&:id)).to eq([post.id])

      results =
        Search.execute(
          "testing include:unlisted",
          guardian: Guardian.new(Fabricate(:trust_level_4)),
        )
      expect(results.posts.map(&:id)).to eq([post.id])

      results = Search.execute("testing", guardian: Guardian.new(admin))
      expect(results.posts).to eq([])
    end

    it "won't work for users that can't see unlisted topics" do
      topic = Fabricate(:topic, title: "I am testing a search", visible: false)
      _post = Fabricate(:post, topic: topic, raw: "this is the first post", post_number: 1)

      results =
        Search.execute("testing include:invisible", guardian: Guardian.new(Fabricate(:user)))
      expect(results.posts).to eq([])

      results =
        Search.execute(
          "testing include:unlisted",
          guardian: Guardian.new(Fabricate(:trust_level_3)),
        )
      expect(results.posts).to eq([])
    end
  end

  describe "ignore_diacritics" do
    before { SiteSetting.search_ignore_accents = true }
    let!(:post1) { Fabricate(:post, raw: "สวัสดี Rágis hello") }

    it("allows strips correctly") do
      results = Search.execute("hello", type_filter: "topic")
      expect(results.posts.length).to eq(1)

      results = Search.execute("ragis", type_filter: "topic")
      expect(results.posts.length).to eq(1)

      results = Search.execute("Rágis", type_filter: "topic")
      expect(results.posts.length).to eq(1)

      # TODO: this is a test we need to fix!
      # expect(results.blurb(results.posts.first)).to include('Rágis')

      results = Search.execute("สวัสดี", type_filter: "topic")
      expect(results.posts.length).to eq(1)
    end
  end

  describe "include_diacritics" do
    before { SiteSetting.search_ignore_accents = false }
    let!(:post1) { Fabricate(:post, raw: "สวัสดี Régis hello") }

    it("allows strips correctly") do
      results = Search.execute("hello", type_filter: "topic")
      expect(results.posts.length).to eq(1)

      results = Search.execute("regis", type_filter: "topic")
      expect(results.posts.length).to eq(0)

      results = Search.execute("Régis", type_filter: "topic")
      expect(results.posts.length).to eq(1)

      expect(results.blurb(results.posts.first)).to include("Régis")

      results = Search.execute("สวัสดี", type_filter: "topic")
      expect(results.posts.length).to eq(1)
    end
  end

  describe "pagination" do
    let(:number_of_results) { 2 }
    let!(:post1) { Fabricate(:post, raw: "hello hello hello hello hello") }
    let!(:post2) { Fabricate(:post, raw: "hello hello hello hello") }
    let!(:post3) { Fabricate(:post, raw: "hello hello hello") }
    let!(:post4) { Fabricate(:post, raw: "hello hello") }
    let!(:post5) { Fabricate(:post, raw: "hello") }

    before { Search.stubs(:per_filter).returns(number_of_results) }

    it "returns more results flag" do
      results = Search.execute("hello", search_type: :full_page, type_filter: "topic")
      results2 = Search.execute("hello", search_type: :full_page, type_filter: "topic", page: 2)

      expect(results.posts.length).to eq(number_of_results)
      expect(results.posts.map(&:id)).to eq([post1.id, post2.id])
      expect(results.more_full_page_results).to eq(true)

      expect(results2.posts.length).to eq(number_of_results)
      expect(results2.posts.map(&:id)).to eq([post3.id, post4.id])
      expect(results2.more_full_page_results).to eq(true)
    end

    it "correctly search with page parameter" do
      search = Search.new("hello", search_type: :full_page, type_filter: "topic", page: 3)
      results = search.execute

      expect(search.offset).to eq(2 * number_of_results)
      expect(results.posts.length).to eq(1)
      expect(results.posts).to eq([post5])
      expect(results.more_full_page_results).to eq(nil)
    end

    it "returns more results flag for header searches" do
      results = Search.execute("hello", search_type: :header)
      expect(results.posts.length).to eq(Search.per_facet)
      expect(results.more_posts).to eq(nil) # not 6 posts yet

      _post6 = Fabricate(:post, raw: "hello post #6")

      results = Search.execute("hello", search_type: :header)
      expect(results.posts.length).to eq(Search.per_facet)
      expect(results.more_posts).to eq(true)
    end
  end

  describe "header in-topic search" do
    let!(:topic) { Fabricate(:topic, title: "This is a topic with a bunch of posts") }
    let!(:post1) { Fabricate(:post, topic: topic, raw: "hola amiga") }
    let!(:post2) { Fabricate(:post, topic: topic, raw: "hola amigo") }
    let!(:post3) { Fabricate(:post, topic: topic, raw: "hola chica") }
    let!(:post4) { Fabricate(:post, topic: topic, raw: "hola chico") }
    let!(:post5) { Fabricate(:post, topic: topic, raw: "hola hermana") }
    let!(:post6) { Fabricate(:post, topic: topic, raw: "hola hermano") }
    let!(:post7) { Fabricate(:post, topic: topic, raw: "hola chiquito") }

    it "does not use per_facet pagination" do
      search = Search.new("hola", search_type: :header, search_context: topic)
      results = search.execute

      expect(results.posts.length).to eq(7)
      expect(results.more_posts).to eq(nil)
    end
  end

  describe "in:tagged" do
    it "allows for searching by presence of any tags" do
      topic = Fabricate(:topic, title: "I am testing a tagged search")
      _post = Fabricate(:post, topic: topic, raw: "this is the first post")
      tag = Fabricate(:tag)
      _topic_tag = Fabricate(:topic_tag, topic: topic, tag: tag)

      results = Search.execute("in:untagged")
      expect(results.posts.length).to eq(0)

      results = Search.execute("in:tagged")
      expect(results.posts.length).to eq(1)

      results = Search.execute("In:TaGgEd")
      expect(results.posts.length).to eq(1)
    end
  end

  describe "in:untagged" do
    it "allows for searching by presence of no tags" do
      topic = Fabricate(:topic, title: "I am testing a untagged search")
      _post = Fabricate(:post, topic: topic, raw: "this is the first post")

      results = Search.execute("iN:uNtAgGeD")
      expect(results.posts.length).to eq(1)

      results = Search.execute("in:tagged")
      expect(results.posts.length).to eq(0)
    end
  end

  describe "plugin extensions" do
    let!(:post0) do
      Fabricate(
        :post,
        raw: "this is the first post about advanced filter with length more than 50 chars",
      )
    end
    let!(:post1) { Fabricate(:post, raw: "this is the second post about advanced filter") }

    it "allows to define custom filter" do
      expect(Search.new("advanced").execute.posts).to eq([post1, post0])

      Search.advanced_filter(/^min_chars:(\d+)$/) do |posts, match|
        posts.where("(SELECT LENGTH(p2.raw) FROM posts p2 WHERE p2.id = posts.id) >= ?", match.to_i)
      end

      expect(Search.new("advanced min_chars:50").execute.posts).to eq([post0])
    ensure
      Search.advanced_filters.delete(/^min_chars:(\d+)$/)
    end

    it "forces custom filters matchers to be case insensitive" do
      expect(Search.new("advanced").execute.posts).to eq([post1, post0])

      Search.advanced_filter(/^MIN_CHARS:(\d+)$/) do |posts, match|
        posts.where("(SELECT LENGTH(p2.raw) FROM posts p2 WHERE p2.id = posts.id) >= ?", match.to_i)
      end

      expect(Search.new("advanced Min_Chars:50").execute.posts).to eq([post0])
    ensure
      Search.advanced_filters.delete(/^MIN_CHARS:(\d+)$/)
    end

    it "allows to define custom order" do
      expect(Search.new("advanced").execute.posts).to eq([post1, post0])

      Search.advanced_order(:chars) { |posts| posts.reorder("MAX(LENGTH(posts.raw)) DESC") }

      expect(Search.new("advanced order:chars").execute.posts).to eq([post0, post1])
    ensure
      Search.advanced_orders.delete(:chars)
    end
  end

  describe "exclude_topics filter" do
    before { SiteSetting.tagging_enabled = true }
    let!(:user) { Fabricate(:user) }
    fab!(:group) { Fabricate(:group, name: "bruce-world-fans") }
    fab!(:topic) { Fabricate(:topic, title: "Bruce topic not a result") }

    it "works" do
      category = Fabricate(:category_with_definition, name: "bruceland", user: user)
      tag = Fabricate(:tag, name: "brucealicious")

      result = Search.execute("bruce", type_filter: "exclude_topics")

      expect(result.users.map(&:id)).to contain_exactly(user.id)

      expect(result.categories.map(&:id)).to contain_exactly(category.id)

      expect(result.groups.map(&:id)).to contain_exactly(group.id)

      expect(result.tags.map(&:id)).to contain_exactly(tag.id)

      expect(result.posts.length).to eq(0)
    end

    it "does not fail when parsed term is empty" do
      result = Search.execute("#cat ", type_filter: "exclude_topics")
      expect(result.categories.length).to eq(0)
    end
  end

  context "when prioritize_exact_search_match is enabled" do
    before { SearchIndexer.enable }

    after { SearchIndexer.disable }

    it "correctly ranks topics" do
      SiteSetting.prioritize_exact_search_title_match = true

      topic1 = Fabricate(:topic, title: "saml saml saml is the best")
      post1 = Fabricate(:post, topic: topic1, raw: "this topic is a story about saml")

      topic2 = Fabricate(:topic, title: "sam has ideas about lots of things")
      post2 = Fabricate(:post, topic: topic2, raw: "this topic is not about saml saml saml")

      topic3 = Fabricate(:topic, title: "jane has ideas about lots of things")
      post3 = Fabricate(:post, topic: topic3, raw: "sam sam sam sam lets add sams")

      SearchIndexer.index(post1, force: true)
      SearchIndexer.index(post2, force: true)
      SearchIndexer.index(post3, force: true)

      result = Search.execute("sam")
      expect(result.posts.length).to eq(3)

      # title match should win cause we limited duplication
      expect(result.posts.pluck(:id)).to eq([post2.id, post1.id, post3.id])
    end
  end

  context "when plugin introduces a search_rank_sort_priorities modifier" do
    before do
      SearchIndexer.enable
      DiscoursePluginRegistry.clear_modifiers!
    end
    after do
      SearchIndexer.disable

      DiscoursePluginRegistry.clear_modifiers!
    end

    it "allow modifying the search rank" do
      plugin = Plugin::Instance.new
      plugin.register_modifier(:search_rank_sort_priorities) do |ranks, search|
        [["topics.closed", 77]]
      end

      closed_topic = Fabricate(:topic, title: "saml saml saml is the best", closed: true)
      closed_post = Fabricate(:post, topic: closed_topic, raw: "this topic is a story about saml")

      open_topic = Fabricate(:topic, title: "saml saml saml is the best2")
      open_post = Fabricate(:post, topic: open_topic, raw: "this topic is a story about saml")

      result = Search.execute("story")
      expect(result.posts.pluck(:id)).to eq([closed_post.id, open_post.id])
    end
  end

  context "when some categories are prioritized" do
    before { SearchIndexer.enable }
    after { SearchIndexer.disable }

    it "correctly ranks topics with prioritized categories and stuffed topic terms" do
      topic1 = Fabricate(:topic, title: "invite invited invites testing stuff with things")
      post1 =
        Fabricate(
          :post,
          topic: topic1,
          raw: "this topic is a story about some person invites are fun",
        )

      category = Fabricate(:category, search_priority: Searchable::PRIORITIES[:high])

      topic2 = Fabricate(:topic, title: "invite is the bestest", category: category)
      post2 =
        Fabricate(
          :post,
          topic: topic2,
          raw: "this topic is a story about some other person invites are fun",
        )

      result = Search.execute("invite")
      expect(result.posts.length).to eq(2)

      # title match should win cause we limited duplication
      expect(result.posts.pluck(:id)).to eq([post2.id, post1.id])
    end
  end

  context "when max_duplicate_search_index_terms limits duplication" do
    before { SearchIndexer.enable }

    after { SearchIndexer.disable }

    it "correctly ranks topics" do
      SiteSetting.max_duplicate_search_index_terms = 5

      topic1 = Fabricate(:topic, title: "this is a topic about sam")
      post1 = Fabricate(:post, topic: topic1, raw: "this topic is a story about some person")

      topic2 = Fabricate(:topic, title: "this is a topic about bob")
      post2 =
        Fabricate(
          :post,
          topic: topic2,
          raw: "this topic is a story about some person #{"sam " * 100}",
        )

      SearchIndexer.index(post1, force: true)
      SearchIndexer.index(post2, force: true)

      result = Search.execute("sam")
      expect(result.posts.length).to eq(2)

      # title match should win cause we limited duplication
      expect(result.posts.pluck(:id)).to eq([post1.id, post2.id])
    end
  end

  describe "Extensibility features of search" do
    it "is possible to parse queries" do
      term = "hello l status:closed"
      search = Search.new(term)

      posts = Post.all.includes(:topic)
      posts = search.apply_filters(posts)
      posts = search.apply_order(posts)

      sql = posts.to_sql

      expect(search.term).to eq("hello")
      expect(sql).to include("ORDER BY posts.created_at DESC")
      expect(sql).to match(/where.*topics.closed/i)
    end
  end
end
