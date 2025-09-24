# encoding: utf-8
# frozen_string_literal: true

describe Topic do
  let(:now) { Time.zone.local(2013, 11, 20, 8, 0) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user1) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:whisperers_group, :group)
  fab!(:user2) { Fabricate(:user, groups: [whisperers_group]) }
  fab!(:moderator)
  fab!(:coding_horror)
  fab!(:evil_trout)
  fab!(:admin)
  fab!(:group)
  fab!(:trust_level_2)

  it_behaves_like "it has custom fields"

  describe "Validations" do
    let(:topic) { Fabricate.build(:topic) }

    describe "#featured_link" do
      describe "when featured_link contains more than a URL" do
        it "should not be valid" do
          topic.featured_link = "http://meta.discourse.org TEST"
          expect(topic).to_not be_valid
        end
      end

      describe "when featured_link is a valid URL" do
        it "should be valid" do
          topic.featured_link = "http://meta.discourse.org"
          expect(topic).to be_valid
        end
      end
    end

    describe "#external_id" do
      describe "when external_id is too long" do
        it "should not be valid" do
          topic.external_id = "a" * (Topic::EXTERNAL_ID_MAX_LENGTH + 1)
          expect(topic).to_not be_valid
        end
      end

      describe "when external_id has invalid characters" do
        it "should not be valid" do
          topic.external_id = "a*&^!@()#"
          expect(topic).to_not be_valid
        end
      end

      describe "when external_id is an empty string" do
        it "should not be valid" do
          topic.external_id = ""
          expect(topic).to_not be_valid
        end
      end

      describe "when external_id has already been used" do
        it "should not be valid" do
          topic2 = Fabricate(:topic, external_id: "asdf")
          topic.external_id = "asdf"
          expect(topic).to_not be_valid
        end
      end

      describe "when external_id is nil" do
        it "should be valid" do
          topic.external_id = nil
          expect(topic).to be_valid
        end
      end

      describe "when external_id is valid" do
        it "should be valid" do
          topic.external_id = "abc_123-ZXY"
          expect(topic).to be_valid
        end
      end
    end

    describe "#title" do
      it { is_expected.to validate_presence_of :title }

      describe "censored words" do
        after { Discourse.redis.flushdb }

        describe "when title contains censored words" do
          after { WordWatcher.clear_cache! }

          it "should not be valid" do
            %w[pineapple pen].each do |w|
              Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor])
            end

            topic.title = "pen PinEapple apple pen is a complete sentence"

            expect(topic).to_not be_valid

            expect(topic.errors.full_messages.first).to include(
              I18n.t("errors.messages.contains_censored_words", censored_words: "pen, pineapple"),
            )
          end
        end

        describe "titles with censored words not on boundaries" do
          it "should be valid" do
            Fabricate(:watched_word, word: "apple", action: WatchedWord.actions[:censor])
            topic.title = "Pineapples are great fruit! Applebee's is a great restaurant"
            expect(topic).to be_valid
          end
        end

        describe "when title does not contain censored words" do
          it "should be valid" do
            topic.title = "The cake is a lie"

            expect(topic).to be_valid
          end
        end

        describe "escape special characters in censored words" do
          before do
            %w[co(onut coconut a**le].each do |w|
              Fabricate(:watched_word, word: w, action: WatchedWord.actions[:censor])
            end
          end

          it "should not be valid" do
            topic.title = "I have a co(onut a**le"

            expect(topic.valid?).to eq(false)

            expect(topic.errors.full_messages.first).to include(
              I18n.t("errors.messages.contains_censored_words", censored_words: "co(onut, a**le"),
            )
          end
        end
      end

      describe "blocked words" do
        describe "when title contains watched words" do
          after { WordWatcher.clear_cache! }

          it "should not be valid" do
            Fabricate(:watched_word, word: "pineapple", action: WatchedWord.actions[:block])

            topic.title = "pen PinEapple apple pen is a complete sentence"

            expect(topic).to_not be_valid

            expect(topic.errors.full_messages.first).to include(
              I18n.t("contains_blocked_word", word: "PinEapple"),
            )
          end
        end
      end
    end
  end

  it { is_expected.to rate_limit }

  describe "#shared_draft?" do
    fab!(:topic)

    context "when topic does not have a shared draft record" do
      it { expect(topic).not_to be_shared_draft }
    end

    context "when topic has a shared draft record" do
      before { Fabricate(:shared_draft, topic: topic) }

      it { expect(topic).to be_shared_draft }
    end
  end

  describe "#visible_post_types" do
    let(:types) { Post.types }

    before do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}|#{whisperers_group.id}"
    end

    it "returns the appropriate types for anonymous users" do
      post_types = Topic.visible_post_types

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to_not include(types[:whisper])
    end

    it "returns the appropriate types for regular users" do
      post_types = Topic.visible_post_types(Fabricate.build(:user))

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to_not include(types[:whisper])
    end

    it "returns the appropriate types for staff users" do
      post_types = Topic.visible_post_types(moderator)

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to include(types[:whisper])
    end

    it "returns the appropriate types for whisperer users" do
      post_types = Topic.visible_post_types(user2)

      expect(post_types).to include(types[:regular])
      expect(post_types).to include(types[:moderator_action])
      expect(post_types).to include(types[:small_action])
      expect(post_types).to include(types[:whisper])
    end
  end

  describe "slug" do
    context "with encoded generator" do
      before { SiteSetting.slug_generation_method = "encoded" }

      context "with ascii letters" do
        let!(:title) { "hello world topic" }
        let!(:slug) { "hello-world-topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns a Slug for a title" do
          expect(topic.title).to eq(title)
          expect(topic.slug).to eq(slug)
        end
      end

      context "for cjk characters" do
        let!(:title) { "熱帶風暴畫眉" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns encoded Slug for a title" do
          expect(topic.title).to eq(title)
          expect(topic.slug).to eq("%E7%86%B1%E5%B8%B6%E9%A2%A8%E6%9A%B4%E7%95%AB%E7%9C%89")
        end
      end

      context "for numbers" do
        let!(:title) { "123456789" }
        let!(:slug) { "topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "generates default slug" do
          Slug.expects(:for).with(title).returns("topic")
          expect(Fabricate.build(:topic, title: title).slug).to eq("topic")
        end
      end
    end

    context "with none generator" do
      let!(:title) { "熱帶風暴畫眉" }
      let!(:slug) { "topic" }
      let!(:topic) { Fabricate.build(:topic, title: title) }

      before { SiteSetting.slug_generation_method = "none" }

      it "returns a Slug for a title" do
        Slug.expects(:for).with(title).returns("topic")
        expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
      end
    end

    describe "#ascii_generator" do
      before { SiteSetting.slug_generation_method = "ascii" }

      context "with ascii letters" do
        let!(:title) { "hello world topic" }
        let!(:slug) { "hello-world-topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns a Slug for a title" do
          Slug.expects(:for).with(title).returns(slug)
          expect(Fabricate.build(:topic, title: title).slug).to eq(slug)
        end
      end

      context "for cjk characters" do
        let!(:title) { "熱帶風暴畫眉" }
        let!(:slug) { "topic" }
        let!(:topic) { Fabricate.build(:topic, title: title) }

        it "returns 'topic' when the slug is empty (say, non-latin characters)" do
          Slug.expects(:for).with(title).returns("topic")
          expect(Fabricate.build(:topic, title: title).slug).to eq("topic")
        end
      end
    end

    describe "slug computed hooks" do
      before do
        invert_slug = ->(topic, slug, title) { slug.reverse }
        Topic.slug_computed_callbacks << invert_slug
      end

      let!(:title) { "hello test topic" }
      let!(:slug) { "hello-test-topic".reverse }
      let!(:other_title) { "other title" }
      let!(:other_slug) { "other-title".reverse }
      let!(:topic) { Fabricate.build(:topic, title: title) }

      it "returns a reversed slug for a title" do
        expect(topic.title).to eq(title)
        expect(topic.slug).to eq(slug)
      end

      it "returns a reversed slug after the title is changed" do
        expect(topic.title).to eq(title)
        expect(topic.slug).to eq(slug)

        topic.title = other_title
        expect(topic.title).to eq(other_title)
        expect(topic.slug).to eq(other_slug)
      end

      after { Topic.slug_computed_callbacks.clear }
    end
  end

  describe "slugless_url" do
    fab!(:topic)

    it "returns the correct url" do
      expect(topic.slugless_url).to eq("/t/#{topic.id}")
    end

    it "works with post id" do
      expect(topic.slugless_url(123)).to eq("/t/#{topic.id}/123")
    end

    it "works with subfolder install" do
      set_subfolder "/forum"

      expect(topic.slugless_url).to eq("/forum/t/#{topic.id}")
    end
  end

  describe "updating a title to be shorter" do
    let!(:topic) { Fabricate(:topic) }

    it "doesn't update it to be shorter due to cleaning using TextCleaner" do
      topic.title = "unread    glitch"
      expect(topic.save).to eq(false)
    end
  end

  describe "private message title" do
    before do
      SiteSetting.min_topic_title_length = 15
      SiteSetting.min_personal_message_title_length = 3
    end

    it "allows shorter titles" do
      pm =
        Fabricate.build(
          :private_message_topic,
          title: "a" * SiteSetting.min_personal_message_title_length,
        )
      expect(pm).to be_valid
    end

    it "but not too short" do
      pm = Fabricate.build(:private_message_topic, title: "a")
      expect(pm).to_not be_valid
    end
  end

  describe "admin topic title" do
    it "allows really short titles" do
      pm = Fabricate.build(:private_message_topic, user: admin, title: "a")
      expect(pm).to be_valid
    end

    it "but not blank" do
      pm = Fabricate.build(:private_message_topic, title: "")
      expect(pm).to_not be_valid
    end
  end

  describe "topic title uniqueness" do
    fab!(:category1, :category)
    fab!(:category2, :category)

    fab!(:topic) { Fabricate(:topic, category: category1) }
    let(:new_topic) { Fabricate.build(:topic, title: topic.title, category: category1) }
    let(:new_topic_different_cat) do
      Fabricate.build(:topic, title: topic.title, category: category2)
    end

    context "when duplicates aren't allowed" do
      before do
        SiteSetting.allow_duplicate_topic_titles = false
        SiteSetting.allow_duplicate_topic_titles_category = false
      end

      it "won't allow another topic to be created with the same name" do
        expect(new_topic).not_to be_valid
      end

      it "won't even allow another topic to be created with the same name but different category" do
        expect(new_topic_different_cat).not_to be_valid
      end

      it "won't allow another topic with an upper case title to be created" do
        new_topic.title = new_topic.title.upcase
        expect(new_topic).not_to be_valid
      end

      it "allows it when the topic is deleted" do
        topic.destroy
        expect(new_topic).to be_valid
      end

      it "allows a private message to be created with the same topic" do
        new_topic.archetype = Archetype.private_message
        expect(new_topic).to be_valid
      end
    end

    context "when duplicates are allowed" do
      before do
        SiteSetting.allow_duplicate_topic_titles = true
        SiteSetting.allow_duplicate_topic_titles_category = false
      end

      it "will allow another topic to be created with the same name" do
        expect(new_topic).to be_valid
      end
    end

    context "when duplicates are allowed if the category is different" do
      before do
        SiteSetting.allow_duplicate_topic_titles = false
        SiteSetting.allow_duplicate_topic_titles_category = true
      end

      it "will allow another topic to be created with the same name but different category" do
        expect(new_topic_different_cat).to be_valid
      end

      it "won't allow another topic to be created with the same name in same category" do
        expect(new_topic).not_to be_valid
      end

      it "other errors will not be cleared" do
        SiteSetting.min_topic_title_length = 5
        topic.update!(title: "more than 5 characters but less than 134")
        SiteSetting.min_topic_title_length = 134
        new_topic_different_cat.title = "more than 5 characters but less than 134"
        expect(new_topic_different_cat).not_to be_valid
        expect(new_topic_different_cat.errors[:title]).to include(
          I18n.t("errors.messages.too_short", count: 134),
        )
      end
    end
  end

  describe "html in title" do
    def build_topic_with_title(title)
      build(:topic, title: title).tap { |t| t.valid? }
    end

    let(:topic_bold) { build_topic_with_title("Topic with <b>bold</b> text in its title") }
    let(:topic_image) do
      build_topic_with_title("Topic with <img src='something'> image in its title")
    end
    let(:topic_script) do
      build_topic_with_title("Topic with <script>alert('title')</script> script in its title")
    end
    let(:topic_emoji) { build_topic_with_title("I 💖 candy alot") }
    let(:topic_modifier_emoji) { build_topic_with_title("I 👨‍🌾 candy alot") }
    let(:topic_shortcut_emoji) { build_topic_with_title("I love candy :)") }
    let(:topic_inline_emoji) { build_topic_with_title("Hello😊World") }

    it "escapes script contents" do
      expect(topic_script.fancy_title).to eq(
        "Topic with &lt;script&gt;alert(&lsquo;title&rsquo;)&lt;/script&gt; script in its title",
      )
    end

    it "expands emojis" do
      expect(topic_emoji.fancy_title).to eq("I :sparkling_heart: candy alot")
    end

    it "keeps combined emojis" do
      expect(topic_modifier_emoji.fancy_title).to eq("I :man_farmer: candy alot")
    end

    it "escapes bold contents" do
      expect(topic_bold.fancy_title).to eq("Topic with &lt;b&gt;bold&lt;/b&gt; text in its title")
    end

    it "escapes image contents" do
      expect(topic_image.fancy_title).to eq(
        "Topic with &lt;img src=&lsquo;something&rsquo;&gt; image in its title",
      )
    end

    it "always escapes title" do
      topic_script.title = topic_script.title + "x" * Topic.max_fancy_title_length
      expect(topic_script.fancy_title).to eq(ERB::Util.html_escape(topic_script.title))
      # not really needed, but just in case
      expect(topic_script.fancy_title).not_to include("<script>")
    end

    context "with emoji shortcuts enabled" do
      before { SiteSetting.enable_emoji_shortcuts = true }

      it "converts emoji shortcuts into emoji" do
        expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :slight_smile:")
      end

      context "with emojis disabled" do
        before { SiteSetting.enable_emoji = false }

        it "does not convert emoji shortcuts" do
          expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :)")
        end
      end
    end

    context "with emoji shortcuts disabled" do
      before { SiteSetting.enable_emoji_shortcuts = false }

      it "does not convert emoji shortcuts" do
        expect(topic_shortcut_emoji.fancy_title).to eq("I love candy :)")
      end
    end

    it "keeps inline emojis if inline emoji setting disabled" do
      SiteSetting.enable_inline_emoji_translation = false
      expect(topic_inline_emoji.fancy_title).to eq("Hello😊World")
    end

    it "expands inline emojis if inline emoji setting enabled" do
      SiteSetting.enable_inline_emoji_translation = true
      expect(topic_inline_emoji.fancy_title).to eq("Hello:blush:World")
    end
  end

  describe "fancy title" do
    let(:topic) { Fabricate.build(:topic, title: %{"this topic" -- has ``fancy stuff''}) }

    context "with title_fancy_entities disabled" do
      before { SiteSetting.title_fancy_entities = false }

      it "doesn't add entities to the title" do
        expect(topic.fancy_title).to eq("&quot;this topic&quot; -- has ``fancy stuff&#39;&#39;")
      end
    end

    context "with title_fancy_entities enabled" do
      before { SiteSetting.title_fancy_entities = true }

      it "converts the title to have fancy entities and updates" do
        expect(topic.fancy_title).to eq(
          "&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;",
        )
        topic.title = "this is my test hello world... yay"
        topic.save!
        topic.reload
        expect(topic.fancy_title).to eq("This is my test hello world&hellip; yay")

        topic.title = "I made a change to the title"
        topic.save!

        topic.reload
        expect(topic.fancy_title).to eq("I made a change to the title")

        # another edge case
        topic.title = "this is another edge case"
        expect(topic.fancy_title).to eq("this is another edge case")
      end

      it "works with long title that results in lots of entities" do
        long_title = "NEW STOCK PICK: PRCT - LAST PICK UP 233%, NNCO#{"." * 150} ofoum"
        topic.title = long_title

        expect { topic.save! }.to_not raise_error
        expect(topic.fancy_title).to eq(long_title)
      end

      context "when in readonly mode" do
        before { Discourse.enable_readonly_mode }

        after { Discourse.disable_readonly_mode }

        it "should not attempt to update `fancy_title`" do
          topic.save!
          expect(topic.fancy_title).to eq(
            "&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;",
          )

          topic.title = "This is a test testing testing"
          expect(topic.fancy_title).to eq("This is a test testing testing")

          expect(topic.reload.read_attribute(:fancy_title)).to eq(
            "&ldquo;this topic&rdquo; &ndash; has &ldquo;fancy stuff&rdquo;",
          )
        end
      end
    end
  end

  describe "category validation" do
    fab!(:category, :category_with_definition)

    context "when allow_uncategorized_topics is false" do
      before { SiteSetting.allow_uncategorized_topics = false }

      it "does not allow nil category" do
        topic = Fabricate.build(:topic, category: nil)
        expect(topic).not_to be_valid
        expect(topic.errors[:category_id]).to be_present
      end

      it "allows PMs" do
        topic = Fabricate.build(:topic, category: nil, archetype: Archetype.private_message)
        expect(topic).to be_valid
      end

      it "passes for topics with a category" do
        expect(Fabricate.build(:topic, category: category)).to be_valid
      end
    end

    context "when allow_uncategorized_topics is true" do
      before { SiteSetting.allow_uncategorized_topics = true }

      it "passes for topics with nil category" do
        expect(Fabricate.build(:topic, category: nil)).to be_valid
      end

      it "passes for topics with a category" do
        expect(Fabricate.build(:topic, category: category)).to be_valid
      end
    end
  end

  describe ".similar_to" do
    fab!(:category, :category_with_definition)

    it "returns an empty array with nil params" do
      expect(Topic.similar_to(nil, nil)).to eq([])
    end

    context "with a category definition" do
      it "excludes the category definition topic from similar_to" do
        expect(Topic.similar_to("category definition for", "no body")).to eq([])
      end
    end

    it "does not result in a syntax error when removing accents" do
      SiteSetting.search_ignore_accents = true
      expect(Topic.similar_to("something", "it's")).to eq([])
    end

    it "does not result in a syntax error when raw is blank after cooking" do
      expect(Topic.similar_to("some title", "#")).to eq([])
    end

    it "does not result in invalid statement when prepared data is blank" do
      expect(Topic.similar_to("some title", "https://discourse.org/#INCORRECT#URI")).to be_empty
    end

    it "does not result in invalid statement when title is all stopwords for zh_CN" do
      SiteSetting.default_locale = "zh_CN"

      expect(Topic.similar_to("怎么上自己的", "")).to eq([])
    end

    it "does not result in invalid statement when title contains unicode characters" do
      SiteSetting.search_ignore_accents = true

      expect(Topic.similar_to("'bad quotes'", "'bad quotes'")).to eq([])
    end

    context "with plugin similar_topic_candidate_ids modifier" do
      it "uses plugin-provided candidate ids preserving order and respecting limit" do
        t1 = Fabricate(:topic)
        t2 = Fabricate(:topic)
        t3 = Fabricate(:topic)
        t4 = Fabricate(:topic)

        raws = { t1.id => "raw one", t2.id => "raw two", t3.id => "raw three", t4.id => "raw four" }

        [t1, t2, t3, t4].each do |t|
          Fabricate(:post, topic: t, user: t.user, post_number: 1, raw: raws[t.id])
        end

        desired_order = [t3.id, t1.id, t2.id, t4.id]

        plugin_instance = Plugin::Instance.new
        begin
          blk =
            lambda do |candidates, args|
              expect(args[:title]).to eq("any title")
              expect(args[:raw]).to eq("any raw")
              desired_order
            end

          DiscoursePluginRegistry.register_modifier(
            plugin_instance,
            :similar_topic_candidate_ids,
            &blk
          )

          results = Topic.similar_to("any title", "any raw")

          # keeping this 3 but test will break if MAX_SIMILAR_TOPICS is changed (by design)
          expected_ids = desired_order.first(3)
          expect(results.map(&:id)).to eq(expected_ids)

          # ensure extra selected columns are present and correct
          results.each_with_index do |topic, idx|
            # topics.* still present
            expect(topic).to be_a(Topic)
            expect(topic.id).to eq(expected_ids[idx])

            # similarity is computed as 3,2,1 for our limited set
            expect(topic["similarity"]).to eq(expected_ids.length - idx)

            # blurb is first post cooked
            expect(topic["blurb"]).to eq(topic.posts.first.cooked)
          end
        ensure
          DiscoursePluginRegistry.unregister_modifier(
            plugin_instance,
            :similar_topic_candidate_ids,
            &blk
          )
        end
      end
    end

    context "with a similar topic" do
      fab!(:post) do
        with_search_indexer_enabled do
          create_post(title: "Evil trout is the dude who posted this topic")
        end
      end

      let(:topic) { post.topic }

      before { SearchIndexer.enable }

      it "returns the similar topic if the title is similar" do
        expect(
          Topic.similar_to(
            "has evil trout made any topics?",
            "i am wondering has evil trout made any topics?",
          ),
        ).to eq([topic])
      end

      it "returns the similar topic even if raw is blank" do
        expect(Topic.similar_to("has evil trout made any topics?", "")).to eq([topic])
      end

      it "matches title against title and raw against raw when searching for topics" do
        topic.update!(title: "1 2 3 numbered titles")
        post.update!(raw: "random toy poodle")

        expect(Topic.similar_to("unrelated term", "1 2 3 poddle")).to eq([])
      end

      it "doesnt match numbered lists against numbers in Post#raw" do
        post.update!(raw: <<~RAW)
        Internet Explorer 11+ Oct 2013 Google Chrome 32+ Jan 2014 Firefox 27+ Feb 2014 Safari 6.1+ Jul 2012 Safari, iOS 8+ Oct 2014
        RAW

        post.topic.update!(title: "Where are we with browser support in 2019?")

        topics = Topic.similar_to("Videos broken in composer", <<~RAW)
        1. Do something
        2. Do something else
        3. Do more things
        RAW

        expect(topics).to eq([])
      end

      it "does not return topics from categories with search priority set to ignore" do
        expect(Topic.similar_to("has evil trout made any topics?", "")).to eq([topic])

        topic.category.update!(search_priority: Searchable::PRIORITIES[:ignore])

        expect(Topic.similar_to("has evil trout made any topics?", "")).to eq([])
      end

      it "does not return topics from categories which the user has muted" do
        expect(Topic.similar_to("has evil trout made any topics?", "", user)).to eq([topic])

        CategoryUser.create!(
          category: topic.category,
          user: user,
          notification_level: CategoryUser.notification_levels[:muted],
        )

        expect(Topic.similar_to("has evil trout made any topics?", "", user)).to eq([])
      end

      it "does not return topics from child categories where the user has muted the parent category" do
        expect(Topic.similar_to("has evil trout made any topics?", "", user)).to eq([topic])

        parent_category = topic.category
        child_category = Fabricate(:category, parent_category: parent_category)
        topic.update!(category: child_category)
        CategoryUser.create!(
          category: parent_category,
          user: user,
          notification_level: CategoryUser.notification_levels[:muted],
        )

        expect(Topic.similar_to("has evil trout made any topics?", "", user)).to eq([])
      end

      context "with secure categories" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }

        before { topic.update!(category: private_category) }

        it "doesn't return topics from private categories" do
          expect(
            Topic.similar_to(
              "has evil trout made any topics?",
              "i am wondering has evil trout made any topics?",
              user,
            ),
          ).to be_blank
        end

        it "should return the cat since the user can see it" do
          group.add(user)

          expect(
            Topic.similar_to(
              "has evil trout made any topics?",
              "i am wondering has evil trout made any topics?",
              user,
            ),
          ).to include(topic)
        end
      end
    end
  end

  describe "post_numbers" do
    let!(:topic) { Fabricate(:topic) }
    let!(:p1) { Fabricate(:post, topic: topic, user: topic.user) }
    let!(:p2) { Fabricate(:post, topic: topic, user: topic.user) }
    let!(:p3) { Fabricate(:post, topic: topic, user: topic.user) }

    it "returns the post numbers of the topic" do
      expect(topic.post_numbers).to eq([1, 2, 3])
      p2.destroy
      topic.reload
      expect(topic.post_numbers).to eq([1, 3])
    end
  end

  describe "#invite" do
    fab!(:topic) { Fabricate(:topic, user: user) }

    context "with rate limits" do
      before { RateLimiter.enable }

      context "when per day" do
        before { SiteSetting.max_topic_invitations_per_day = 1 }

        it "rate limits topic invitations" do
          start = Time.now.tomorrow.beginning_of_day
          freeze_time(start)

          topic = Fabricate(:topic, user: trust_level_2)

          topic.invite(topic.user, user.username)

          expect { topic.invite(topic.user, user1.username) }.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end

        it "rate limits PM invitations" do
          start = Time.now.tomorrow.beginning_of_day
          freeze_time(start)

          topic = Fabricate(:private_message_topic, user: trust_level_2)

          topic.invite(topic.user, user.username)

          expect { topic.invite(topic.user, user1.username) }.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end
      end

      context "when per minute" do
        before { SiteSetting.max_topic_invitations_per_minute = 1 }

        it "rate limits topic invitations" do
          start = Time.now.tomorrow.beginning_of_minute
          freeze_time(start)

          topic = Fabricate(:topic, user: trust_level_2)

          topic.invite(topic.user, user.username)

          expect { topic.invite(topic.user, user1.username) }.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end

        it "rate limits PM invitations" do
          start = Time.now.tomorrow.beginning_of_minute
          freeze_time(start)

          topic = Fabricate(:private_message_topic, user: trust_level_2)

          topic.invite(topic.user, user.username)

          expect { topic.invite(topic.user, user1.username) }.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end

        it "does not rate limit if the invites are spread out" do
          start = Time.now.tomorrow.beginning_of_minute
          freeze_time(start)

          topic = Fabricate(:private_message_topic, user: trust_level_2)

          topic.invite(topic.user, user.username)

          freeze_time(start + 5.minutes)

          expect { topic.invite(topic.user, user1.username) }.not_to raise_error(
            RateLimiter::LimitExceeded,
          )
        end
      end
    end

    describe "when username_or_email is not valid" do
      it "should return the right value" do
        expect do expect(topic.invite(user, "somerandomstring")).to eq(nil) end.to_not change {
          topic.allowed_users
        }
      end
    end

    describe "when user is already allowed" do
      it "should raise the right error" do
        topic.allowed_users << user1

        expect { topic.invite(user, user1.username) }.to raise_error(Topic::UserExists)
      end
    end

    describe "private message" do
      fab!(:user) { trust_level_2 }
      fab!(:topic) { Fabricate(:private_message_topic, user: trust_level_2) }

      describe "by username" do
        it "should be able to invite a user" do
          expect(topic.invite(user, user1.username)).to eq(true)
          expect(topic.allowed_users).to include(user1)
          expect(Post.last.action_code).to eq("invited_user")

          notification = Notification.last

          expect(notification.notification_type).to eq(
            Notification.types[:invited_to_private_message],
          )

          expect(topic.remove_allowed_user(user, user1.username)).to eq(true)
          expect(topic.reload.allowed_users).to_not include(user1)
          expect(Post.last.action_code).to eq("removed_user")
        end

        it "should not create a small action if user is already invited through a group" do
          group = Fabricate(:group, users: [user, user1])
          expect(topic.invite_group(user, group)).to eq(true)

          expect { topic.invite(user, user1.username) }.to change { Notification.count }.by(
            1,
          ).and not_change { Post.where(post_type: Post.types[:small_action]).count }
        end

        context "when from a muted user" do
          before { Fabricate(:muted_user, user: user1, muted_user: user) }

          it "fails with an error" do
            expect { topic.invite(user, user1.username) }.to raise_error(Topic::NotAllowed)
            expect(topic.allowed_users).to_not include(user1)
            expect(Post.last).to be_blank
            expect(Notification.last).to be_blank
          end
        end

        context "when from a ignored user" do
          before { Fabricate(:ignored_user, user: user1, ignored_user: user) }

          it "fails with an error" do
            expect { topic.invite(user, user1.username) }.to raise_error(Topic::NotAllowed)
            expect(topic.allowed_users).to_not include(user1)
            expect(Post.last).to be_blank
            expect(Notification.last).to be_blank
          end
        end

        context "when PMs are enabled for TL3 or higher only" do
          before do
            SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4]
          end

          it "should raise error" do
            expect { topic.invite(user, user1.username) }.to raise_error(Topic::UserExists)
          end
        end

        context "when invited_user has enabled allow_list" do
          fab!(:pm) do
            Fabricate(
              :private_message_topic,
              user: user,
              topic_allowed_users: [
                Fabricate.build(:topic_allowed_user, user: user),
                Fabricate.build(:topic_allowed_user, user: user2),
              ],
            )
          end

          before { user1.user_option.update!(enable_allowed_pm_users: true) }

          it "succeeds when inviter is in allowed list" do
            AllowedPmUser.create!(user: user1, allowed_pm_user: user)
            expect(topic.invite(user, user1.username)).to eq(true)
          end

          it "should raise error when inviter not in allowed list" do
            AllowedPmUser.create!(user: user1, allowed_pm_user: user2)
            expect { topic.invite(user, user1.username) }.to raise_error(
              Topic::NotAllowed,
            ).with_message(I18n.t("topic_invite.receiver_does_not_allow_pm"))
          end

          it "should succeed for staff even when not allowed" do
            AllowedPmUser.create!(user: user1, allowed_pm_user: user2)
            expect(topic.invite(user1, admin.username)).to eq(true)
          end

          it "should raise error when target_user is not in inviters allowed list" do
            user.user_option.update!(enable_allowed_pm_users: true)
            AllowedPmUser.create!(user: user1, allowed_pm_user: user)
            expect { topic.invite(user, user1.username) }.to raise_error(
              Topic::NotAllowed,
            ).with_message(I18n.t("topic_invite.sender_does_not_allow_pm"))
          end

          it "succeeds when inviter is in allowed list even though other participants are not in allowed list" do
            AllowedPmUser.create!(user: user1, allowed_pm_user: user)
            expect(pm.invite(user, user1.username)).to eq(true)
          end
        end
      end

      describe "by email" do
        it "should be able to invite a user" do
          expect(topic.invite(user, user1.email)).to eq(true)
          expect(topic.allowed_users).to include(user1)

          expect(Notification.last.notification_type).to eq(
            Notification.types[:invited_to_private_message],
          )
        end

        describe "when user is not found" do
          it "should create the right invite" do
            expect(topic.invite(user, "test@email.com")).to eq(true)

            invite = Invite.last

            expect(invite.email).to eq("test@email.com")
            expect(invite.invited_by).to eq(user)
          end

          describe "when user does not have sufficient trust level" do
            before { user.change_trust_level!(TrustLevel[1]) }

            it "should not create an invite" do
              expect do expect(topic.invite(user, "test@email.com")).to eq(nil) end.to_not change {
                Invite.count
              }
            end
          end
        end
      end
    end

    describe "public topic" do
      def expect_the_right_notification_to_be_created(inviter, invitee)
        notification = Notification.last

        expect(notification.notification_type).to eq(Notification.types[:invited_to_topic])

        expect(notification.user).to eq(invitee)
        expect(notification.topic).to eq(topic)

        notification_data = JSON.parse(notification.data)

        expect(notification_data["topic_title"]).to eq(topic.title)
        expect(notification_data["display_username"]).to eq(inviter.username)
      end

      describe "by username" do
        it "should invite user into a topic" do
          topic.invite(user, user1.username)
          expect_the_right_notification_to_be_created(user, user1)
        end
      end

      describe "by email" do
        it "should be able to invite a user" do
          expect(topic.invite(user, user1.email)).to eq(true)
          expect_the_right_notification_to_be_created(user, user1)
        end

        describe "when topic belongs to a private category" do
          fab!(:category) do
            Fabricate(:category_with_definition, groups: [group]).tap do |category|
              category.set_permissions(group => :full)
              category.save!
            end
          end

          fab!(:topic) { Fabricate(:topic, category: category) }
          fab!(:inviter) { Fabricate(:user).tap { |user| group.add_owner(user) } }
          fab!(:invitee, :user)

          describe "as a group owner" do
            it "should be able to invite a user" do
              expect do
                expect(topic.invite(inviter, invitee.email, [group.id])).to eq(true)
              end.to change { Notification.count } & change { GroupHistory.count }

              expect_the_right_notification_to_be_created(inviter, invitee)

              group_history = GroupHistory.last

              expect(group_history.acting_user).to eq(inviter)
              expect(group_history.target_user).to eq(invitee)

              expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
            end

            describe "when group ids are not given" do
              it "should not invite the user" do
                expect do
                  expect(topic.invite(inviter, invitee.email)).to eq(false)
                end.to_not change { Notification.count }
              end
            end
          end

          describe "as a normal user" do
            it "should not be able to invite a user" do
              expect do
                expect(topic.invite(Fabricate(:user), invitee.email, [group.id])).to eq(false)
              end.to_not change { Notification.count }
            end
          end
        end

        context "for a muted topic" do
          before do
            TopicUser.change(
              user1.id,
              topic.id,
              notification_level: TopicUser.notification_levels[:muted],
            )
          end

          it "fails with an error message" do
            expect { topic.invite(user, user1.username) }.to raise_error(Topic::NotAllowed)
            expect(topic.allowed_users).to_not include(user1)
            expect(Post.last).to be_blank
            expect(Notification.last).to be_blank
          end
        end

        describe "when user can invite via email" do
          before { user.change_trust_level!(TrustLevel[2]) }

          it "should create an invite" do
            Jobs.run_immediately!
            expect(topic.invite(user, "test@email.com")).to eq(true)

            invite = Invite.last

            expect(invite.email).to eq("test@email.com")
            expect(invite.invited_by).to eq(user)
            expect(ActionMailer::Base.deliveries.last.body).to include(topic.title)
          end
        end
      end
    end
  end

  describe "private message" do
    fab!(:pm_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:topic) do
      PostCreator
        .new(
          pm_user,
          title: "This is a private message",
          raw: "This is my message to you-ou-ou",
          archetype: Archetype.private_message,
          target_usernames: coding_horror.username,
        )
        .create!
        .topic
    end

    it "should integrate correctly" do
      expect(Guardian.new(topic.user).can_see?(topic)).to eq(true)
      expect(Guardian.new.can_see?(topic)).to eq(false)
      expect(Guardian.new(evil_trout).can_see?(topic)).to eq(false)
      expect(Guardian.new(coding_horror).can_see?(topic)).to eq(true)
      expect(TopicQuery.new(evil_trout).list_latest.topics).not_to include(topic)
    end

    context "with invite" do
      context "with existing user" do
        context "when using group name" do
          it "can add admin to allowed groups" do
            admins = Group[:admins]
            admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])

            expect(topic.invite_group(topic.user, admins)).to eq(true)
            expect(topic.allowed_groups.include?(admins)).to eq(true)
            expect(topic.remove_allowed_group(topic.user, "admins")).to eq(true)
            expect(topic.allowed_groups.include?(admins)).to eq(false)
          end

          def set_state!(group, user, state)
            group
              .group_users
              .find_by(user_id: user.id)
              .update!(notification_level: NotificationLevels.all[state])
          end

          it "creates a notification for each user in the group" do
            # trigger notification
            user_watching_first = Fabricate(:user)
            user_watching = Fabricate(:user)

            # trigger rollup
            user_tracking = Fabricate(:user)

            # trigger nothing
            user_normal = Fabricate(:user)
            user_muted = Fabricate(:user)

            Fabricate(:post, topic: topic)

            group.add(topic.user) # no notification even though watching
            group.add(user_watching_first)
            group.add(user_watching)
            group.add(user_normal)
            group.add(user_muted)
            group.add(user_tracking)

            set_state!(group, topic.user, :watching)
            set_state!(group, user_watching, :watching)
            set_state!(group, user_watching_first, :watching_first_post)
            set_state!(group, user_tracking, :tracking)
            set_state!(group, user_normal, :regular)
            set_state!(group, user_muted, :muted)

            Notification.delete_all
            Jobs.run_immediately!
            topic.invite_group(topic.user, group)

            expect(Notification.count).to eq(3)

            [user_watching, user_watching_first].each do |u|
              notifications = Notification.where(user_id: u.id).to_a
              expect(notifications.length).to eq(1)

              notification = notifications.first

              expect(notification.topic).to eq(topic)
              expect(notification.notification_type).to eq(
                Notification.types[:invited_to_private_message],
              )
            end

            notifications = Notification.where(user_id: user_tracking.id).to_a
            expect(notifications.length).to eq(1)
            notification = notifications.first

            expect(notification.notification_type).to eq(Notification.types[:group_message_summary])
          end

          it "does not create notifications if invite is set to skip notifications" do
            Fabricate(:post, topic: topic)
            user_watching = Fabricate(:user)

            group.add(topic.user)
            group.add(user_watching)

            set_state!(group, topic.user, :watching)
            set_state!(group, user_watching, :watching)

            Notification.delete_all
            Jobs.run_immediately!
            topic.invite_group(topic.user, group, should_notify: false)

            expect(Notification.count).to eq(0)
          end

          it "removes users in topic_allowed_users who are part of the added group" do
            admins = Group[:admins]
            admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])

            # clear up the state so we can be more explicit with the test
            TopicAllowedUser.where(topic: topic).delete_all
            user0 = topic.user
            user3 = Fabricate(:user)
            Fabricate(:topic_allowed_user, topic: topic, user: user0)
            Fabricate(:topic_allowed_user, topic: topic, user: user1)
            Fabricate(:topic_allowed_user, topic: topic, user: user2)
            Fabricate(:topic_allowed_user, topic: topic, user: user3)

            admins.add(user1)
            admins.add(user2)

            other_topic = Fabricate(:topic)
            Fabricate(:topic_allowed_user, user: user1, topic: other_topic)

            expect(topic.invite_group(topic.user, admins)).to eq(true)
            expect(topic.posts.last.action_code).to eq("removed_user")
            expect(topic.allowed_users).to match_array([user0, user3])
            expect(other_topic.allowed_users).to match_array([user1])
          end

          it "does not remove the OP from topic_allowed_users if they are part of an added group" do
            admins = Group[:admins]
            admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])

            # clear up the state so we can be more explicit with the test
            TopicAllowedUser.where(topic: topic).delete_all
            user0 = topic.user
            Fabricate(:topic_allowed_user, topic: topic, user: user0)
            Fabricate(:topic_allowed_user, topic: topic, user: user1)

            admins.add(topic.user)
            admins.add(user1)

            expect(topic.invite_group(topic.user, admins)).to eq(true)
            expect(topic.allowed_users).to match_array([topic.user])
          end
        end
      end
    end

    context "with user actions" do
      it "should set up actions correctly" do
        UserActionManager.enable

        post = create_post(archetype: "private_message", target_usernames: [user.username])
        actions = post.user.user_actions

        expect(actions.map { |a| a.action_type }).not_to include(UserAction::NEW_TOPIC)
        expect(actions.map { |a| a.action_type }).to include(UserAction::NEW_PRIVATE_MESSAGE)
        expect(user.user_actions.map { |a| a.action_type }).to include(
          UserAction::GOT_PRIVATE_MESSAGE,
        )
      end
    end
  end

  describe "bumping topics" do
    fab!(:topic) { Fabricate(:topic, bumped_at: 1.year.ago) }

    it "updates the bumped_at field when a new post is made" do
      expect(topic.bumped_at).to be_present
      expect {
        create_post(topic: topic, user: topic.user)
        topic.reload
      }.to change(topic, :bumped_at)
    end

    context "when editing posts" do
      fab!(:earlier_post) { Fabricate(:post, topic:, user: topic.user) }
      fab!(:last_post) { Fabricate(:post, topic:, user: topic.user) }

      before { topic.reload }

      it "doesn't bump the topic on an edit to the last post that doesn't result in a new version" do
        expect {
          SiteSetting.editing_grace_period = 5.minutes
          last_post.revise(
            last_post.user,
            { raw: last_post.raw + "a" },
            revised_at: last_post.created_at + 10.seconds,
          )
          topic.reload
        }.not_to change(topic, :bumped_at)
      end

      it "doesn't bump the topic when a new version is made of the last post" do
        expect {
          last_post.revise(moderator, raw: "updated contents")
          topic.reload
        }.not_to change(topic, :bumped_at)
      end

      it "doesn't bump the topic when a post that isn't the last post receives a new version" do
        expect {
          earlier_post.revise(moderator, raw: "updated contents")
          topic.reload
        }.not_to change(topic, :bumped_at)
      end

      it "doesn't bump the topic when a post have invalid topic title while edit" do
        expect {
          last_post.revise(moderator, title: "invalid title")
          topic.reload
        }.not_to change(topic, :bumped_at)
      end
    end
  end

  describe "moderator posts" do
    fab!(:topic)

    it "creates a moderator post" do
      mod_post =
        topic.add_moderator_post(
          moderator,
          "Moderator did something. http://discourse.org",
          post_number: 999,
        )

      expect(mod_post).to be_present
      expect(mod_post.post_type).to eq(Post.types[:moderator_action])
      expect(mod_post.post_number).to eq(999)
      expect(mod_post.sort_order).to eq(999)
      expect(topic.topic_links.count).to eq(1)
      expect(topic.reload.moderator_posts_count).to eq(1)
    end

    context "when moderator post fails to be created" do
      before { user.update_column(:silenced_till, 1.year.from_now) }

      it "should not increment moderator_posts_count" do
        expect(topic.moderator_posts_count).to eq(0)

        topic.add_moderator_post(user, "winter is never coming")

        expect(topic.moderator_posts_count).to eq(0)
      end
    end
  end

  describe "update_status" do
    fab!(:post) { Fabricate(:post).tap { |p| p.topic.update!(bumped_at: 1.hour.ago) } }
    fab!(:topic) { post.topic }

    let(:user) { topic.user }
    let!(:original_bumped_at) { topic.bumped_at }

    before { user.admin = true }

    context "with visibility" do
      let(:category) { Fabricate(:category_with_definition) }

      context "when disabled" do
        it "should not be visible and have correct counts" do
          topic.update_status("visible", false, user)
          topic.reload
          expect(topic).not_to be_visible
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at).to eq_time(original_bumped_at)
        end

        it "decreases topic_count of topic category" do
          topic.update!(category: category)
          Category.update_stats

          expect do 2.times { topic.update_status("visible", false, user) } end.to change {
            category.reload.topic_count
          }.by(-1)
        end

        it "decreases topic_count of user stat" do
          expect do 2.times { topic.update_status("visible", false, user) } end.to change {
            post.user.user_stat.reload.topic_count
          }.from(1).to(0)
        end

        it "removes itself as featured topic on user profiles" do
          user.user_profile.update(featured_topic_id: topic.id)
          expect(user.user_profile.featured_topic).to eq(topic)

          topic.update_status("visible", false, user)
          expect(user.user_profile.reload.featured_topic).to eq(nil)
        end
      end

      context "when enabled" do
        before do
          topic.update_status("visible", false, user)
          topic.reload
        end

        it "should be visible with correct counts" do
          topic.update_status("visible", true, user)

          expect(topic).to be_visible
          expect(topic.moderator_posts_count).to eq(2)
          expect(topic.bumped_at).to eq_time(original_bumped_at)
        end

        it "increases topic_count of topic category" do
          topic.update!(category: category)

          expect do 2.times { topic.update_status("visible", true, user) } end.to change {
            category.reload.topic_count
          }.by(1)
        end

        it "increases topic_count of user stat" do
          expect do 2.times { topic.update_status("visible", true, user) } end.to change {
            post.user.user_stat.reload.topic_count
          }.from(0).to(1)
        end
      end
    end

    context "with pinned" do
      context "when disabled" do
        before do
          topic.update_status("pinned", false, user)
          topic.reload
        end

        it "doesn't have a pinned_at but has correct dates" do
          expect(topic.pinned_at).to be_blank
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at).to eq_time(original_bumped_at)
        end
      end

      context "when enabled" do
        before do
          topic.update_attribute :pinned_at, nil
          topic.update_status("pinned", true, user)
          topic.reload
        end

        it "should enable correctly" do
          expect(topic.pinned_at).to be_present
          expect(topic.bumped_at).to eq_time(original_bumped_at)
          expect(topic.moderator_posts_count).to eq(1)
        end
      end
    end

    context "with archived" do
      it "should create a staff action log entry" do
        expect { topic.update_status("archived", true, user) }.to change {
          UserHistory.where(action: UserHistory.actions[:topic_archived]).count
        }.by(1)
      end

      context "when disabled" do
        let(:archived_topic) { Fabricate(:topic, archived: true, bumped_at: 1.hour.ago) }
        let!(:original_bumped_at) { archived_topic.bumped_at }

        before do
          archived_topic.update_status("archived", false, user)
          archived_topic.reload
        end

        it "should archive correctly" do
          expect(archived_topic).not_to be_archived
          expect(archived_topic.bumped_at).to eq_time(original_bumped_at)
          expect(archived_topic.moderator_posts_count).to eq(1)
        end
      end

      context "when enabled" do
        before do
          topic.update_attribute :archived, false
          topic.update_status("archived", true, user)
          topic.reload
        end

        it "should be archived" do
          expect(topic).to be_archived
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.bumped_at).to eq_time(original_bumped_at)
        end
      end
    end

    shared_examples_for "a status that closes a topic" do
      context "when disabled" do
        let(:closed_topic) { Fabricate(:topic, closed: true, bumped_at: 1.hour.ago) }
        let!(:original_bumped_at) { closed_topic.bumped_at }

        before do
          closed_topic.update_status(status, false, user)
          closed_topic.reload
        end

        it "should not be pinned" do
          expect(closed_topic).not_to be_closed
          expect(closed_topic.moderator_posts_count).to eq(1)
          expect(closed_topic.bumped_at).not_to eq_time(original_bumped_at)
        end
      end

      context "when enabled" do
        before do
          topic.update_attribute :closed, false
          topic.update_status(status, true, user)
          topic.reload
        end

        it "should be closed" do
          expect(topic).to be_closed
          expect(topic.bumped_at).to eq_time(original_bumped_at)
          expect(topic.moderator_posts_count).to eq(1)
          expect(topic.topic_timers.first).to eq(nil)
        end
      end
    end

    context "when closed" do
      let(:status) { "closed" }
      it_behaves_like "a status that closes a topic"

      it "should archive group message" do
        group.add(user)
        topic = Fabricate(:private_message_topic, allowed_groups: [group])

        expect { topic.update_status(status, true, user) }.to change(
          topic.group_archived_messages,
          :count,
        ).by(1)
      end

      it "should create a staff action log entry" do
        expect { topic.update_status(status, true, user) }.to change {
          UserHistory.where(action: UserHistory.actions[:topic_closed]).count
        }.by(1)
      end
    end

    context "when autoclosed" do
      let(:status) { "autoclosed" }
      it_behaves_like "a status that closes a topic"

      context "when topic was set to close when it was created" do
        it "includes the autoclose duration in the moderator post" do
          freeze_time(Time.new(2000, 1, 1))
          topic.created_at = 3.days.ago
          topic.update_status(status, true, user)
          expect(topic.posts.last.raw).to include "closed after 3 days"
        end
      end

      context "when topic was set to close after it was created" do
        it "includes the autoclose duration in the moderator post" do
          freeze_time(Time.new(2000, 1, 1))

          topic.created_at = 7.days.ago

          freeze_time(2.days.ago)

          topic.set_or_create_timer(TopicTimer.types[:close], 48)
          topic.save!

          freeze_time(2.days.from_now)

          topic.update_status(status, true, user)
          expect(topic.posts.last.raw).to include "closed after 2 days"
        end
      end
    end
  end

  describe "banners" do
    fab!(:topic)
    fab!(:user) { topic.user }
    fab!(:first_post) { Fabricate(:post, topic: topic, user: topic.user, cooked: "<p>BANNER</p>") }

    describe "make_banner!" do
      it "changes the topic archetype to 'banner'" do
        messages =
          MessageBus.track_publish do
            topic.make_banner!(user)
            expect(topic.archetype).to eq(Archetype.banner)
          end

        channels = messages.map(&:channel)
        expect(channels).to include("/site/banner")
        expect(channels).to include("/distributed_hash")
      end

      it "ensures only one banner topic at all time" do
        _banner_topic = Fabricate(:banner_topic)
        expect(Topic.where(archetype: Archetype.banner).count).to eq(1)

        topic.make_banner!(user)
        expect(Topic.where(archetype: Archetype.banner).count).to eq(1)
      end

      it "removes any dismissed banner keys" do
        user.user_profile.update_column(:dismissed_banner_key, topic.id)

        topic.make_banner!(user)
        user.user_profile.reload
        expect(user.user_profile.dismissed_banner_key).to be_nil
      end
    end

    describe "remove_banner!" do
      it "resets the topic archetype" do
        topic.expects(:add_moderator_post)

        message = MessageBus.track_publish { topic.remove_banner!(user) }.first

        expect(topic.archetype).to eq(Archetype.default)
        expect(message.channel).to eq("/site/banner")
        expect(message.data).to eq(nil)
      end
    end

    context "with bannered_until date" do
      it "sets bannered_until to be caught by ensure_consistency" do
        bannered_until = 5.days.from_now
        topic.make_banner!(user, bannered_until.to_s)

        freeze_time 6.days.from_now do
          expect(topic.archetype).to eq(Archetype.banner)

          Topic.ensure_consistency!
          topic.reload

          expect(topic.archetype).to eq(Archetype.default)
        end
      end
    end

    describe "#banner" do
      it "returns the banner hash" do
        expect(topic.banner).to include(html: "<p>BANNER</p>", key: topic.id, url: topic.url)
      end

      it "returns a localized banner" do
        SiteSetting.content_localization_enabled = true

        first_post.update!(locale: "en")
        I18n.locale = :ja
        Fabricate(:post_localization, post: first_post, locale: :ja, cooked: "<p>バナー</p>")

        expect(topic.banner(Guardian.new(user))).to include(html: "<p>バナー</p>")
      end
    end
  end

  context "with last_poster info" do
    let(:post) { create_post }
    let!(:user) { post.user }
    let!(:topic) { post.topic }

    it "initially has the last_post_user_id of the OP" do
      expect(topic.last_post_user_id).to eq(user.id)
    end

    context "after a second post" do
      let(:second_user) { coding_horror }
      let!(:new_post) { create_post(topic:, user: second_user) }

      before { topic.reload }

      it "updates the last_post_user_id to the second_user" do
        expect(topic.last_post_user_id).to eq(second_user.id)
        expect(topic.last_posted_at.to_i).to eq(new_post.created_at.to_i)
        topic_user = second_user.topic_users.find_by(topic_id: topic.id)
        expect(topic_user.posted?).to eq(true)
      end
    end
  end

  describe "with category" do
    fab!(:category, :category_with_definition)

    it "should not increase the topic_count with no category" do
      expect {
        Fabricate(:topic, user: category.user)
        category.reload
      }.not_to change(category, :topic_count)
    end

    it "should increase the category's topic_count" do
      expect {
        Fabricate(:topic, user: category.user, category_id: category.id)
        category.reload
      }.to change(category, :topic_count).by(1)
    end
  end

  describe "after create" do
    fab!(:topic)

    it "is a regular topic by default" do
      expect(topic.archetype).to eq(Archetype.default)
      expect(topic.has_summary).to eq(false)
      expect(topic).to be_visible
      expect(topic.pinned_at).to be_blank
      expect(topic).not_to be_closed
      expect(topic).not_to be_archived
      expect(topic.moderator_posts_count).to eq(0)
    end

    context "with post" do
      let(:post) { Fabricate(:post, topic: topic, user: topic.user) }

      it "has the same archetype as the topic" do
        expect(post.archetype).to eq(topic.archetype)
      end
    end
  end

  describe "#change_category_to_id" do
    fab!(:topic)
    fab!(:user) { topic.user }
    fab!(:category) { Fabricate(:category_with_definition, user: user) }

    describe "without a previous category" do
      it "changes the category" do
        topic.change_category_to_id(category.id)
        category.reload
        expect(topic.category).to eq(category)
        expect(category.topic_count).to eq(1)
      end

      it "should not change the topic_count when not changed" do
        expect {
          topic.change_category_to_id(topic.category.id)
          category.reload
        }.not_to change(category, :topic_count)
      end

      it "doesn't change the category when it can't be found" do
        topic.change_category_to_id(12_312_312)
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      it "changes the category even when the topic title is invalid" do
        SiteSetting.min_topic_title_length = 5
        topic.update_column(:title, "xyz")
        expect { topic.change_category_to_id(category.id) }.to change { topic.category_id }.to(
          category.id,
        )
      end
    end

    describe "with a previous category" do
      before_all do
        topic.change_category_to_id(category.id)
        topic.reload
        category.reload
      end

      it "doesn't change the topic_count when the value doesn't change" do
        expect(category.topic_count).to eq(1)
        expect {
          topic.change_category_to_id(category.id)
          category.reload
        }.not_to change(category, :topic_count)
      end

      it "doesn't reset the category when an id that doesn't exist" do
        topic.change_category_to_id(55_556)
        expect(topic.category_id).to eq(category.id)
      end

      describe "to a different category" do
        fab!(:new_category) do
          Fabricate(:category_with_definition, user: user, name: "2nd category")
        end

        it "should work" do
          topic.change_category_to_id(new_category.id)

          expect(topic.reload.category).to eq(new_category)
          expect(new_category.reload.topic_count).to eq(1)
          expect(category.reload.topic_count).to eq(0)
        end

        describe "user that is watching the new category" do
          before do
            Jobs.run_immediately!

            topic.posts << Fabricate(:post)

            CategoryUser.set_notification_level_for_category(
              user,
              CategoryUser.notification_levels[:watching],
              new_category.id,
            )

            CategoryUser.set_notification_level_for_category(
              user1,
              CategoryUser.notification_levels[:watching_first_post],
              new_category.id,
            )
          end

          it "should generate the notification for the topic" do
            expect do topic.change_category_to_id(new_category.id) end.to change {
              Notification.count
            }.by(2)

            expect(
              Notification.where(
                user_id: user.id,
                topic_id: topic.id,
                post_number: 1,
                notification_type: Notification.types[:posted],
              ).exists?,
            ).to eq(true)

            expect(
              Notification.where(
                user_id: user1.id,
                topic_id: topic.id,
                post_number: 1,
                notification_type: Notification.types[:watching_first_post],
              ).exists?,
            ).to eq(true)
          end

          it "should not generate a notification if SiteSetting.disable_category_edit_notifications is enabled" do
            SiteSetting.disable_category_edit_notifications = true

            expect do topic.change_category_to_id(new_category.id) end.not_to change {
              Notification.count
            }

            expect(topic.category_id).to eq(new_category.id)
          end

          it "should not generate a notification if options: silent is true" do
            expect do topic.change_category_to_id(new_category.id, silent: true) end.not_to change {
              Notification.count
            }

            expect(topic.category_id).to eq(new_category.id)
          end

          it "should generate the modified notification for the topic if already seen" do
            TopicUser.create!(
              topic_id: topic.id,
              last_read_post_number: topic.posts.first.post_number,
              user_id: user.id,
            )

            expect do topic.change_category_to_id(new_category.id) end.to change {
              Notification.count
            }.by(2)

            expect(
              Notification.where(
                user_id: user.id,
                topic_id: topic.id,
                post_number: 1,
                notification_type: Notification.types[:edited],
              ).exists?,
            ).to eq(true)

            expect(
              Notification.where(
                user_id: user1.id,
                topic_id: topic.id,
                post_number: 1,
                notification_type: Notification.types[:watching_first_post],
              ).exists?,
            ).to eq(true)
          end

          it "should not generate a notification for unlisted topic" do
            topic.update_column(:visible, false)

            expect do topic.change_category_to_id(new_category.id) end.not_to change {
              Notification.count
            }
          end
        end

        describe "when new category is set to auto close by default" do
          before do
            freeze_time
            new_category.update!(auto_close_hours: 5)
            topic.user.update!(admin: true)
          end

          it "should set a topic timer" do
            now = Time.zone.now

            expect { topic.change_category_to_id(new_category.id) }.to change {
              TopicTimer.count
            }.by(1)

            expect(topic.reload.category).to eq(new_category)

            topic_timer = TopicTimer.last

            expect(topic_timer.user).to eq(Discourse.system_user)
            expect(topic_timer.topic).to eq(topic)
            expect(topic_timer.execute_at).to be_within_one_minute_of(now + 5.hours)
          end

          describe "when topic is already closed" do
            before { topic.update_status("closed", true, Discourse.system_user) }

            it "should not set a topic timer" do
              expect { topic.change_category_to_id(new_category.id) }.not_to change {
                TopicTimer.with_deleted.count
              }

              expect(topic.closed).to eq(true)
              expect(topic.reload.category).to eq(new_category)
            end
          end

          describe "when topic has an existing topic timer" do
            let(:topic_timer) { Fabricate(:topic_timer, topic: topic) }

            it "should not inherit category's auto close hours" do
              topic_timer
              topic.change_category_to_id(new_category.id)

              expect(topic.reload.category).to eq(new_category)
              expect(topic.public_topic_timer).to eq(topic_timer)
              expect(topic.public_topic_timer.execute_at).to eq_time(topic_timer.execute_at)
            end
          end
        end

        describe "when the topic title is not valid" do
          fab!(:topic_title) { topic.title }
          fab!(:topic_slug) { topic.slug }
          fab!(:topic_2, :topic)

          it "does not save title or slug when title repeats letters" do
            topic.title = "a" * 50
            topic.change_category_to_id(new_category.id)

            expect(topic.reload.title).to eq(topic_title)
            expect(topic.reload.slug).to eq(topic_slug)
          end

          it "does not save title or slug when title is too long" do
            SiteSetting.max_topic_title_length = 200

            topic.title = "Neque porro quisquam est qui dolorem ipsum quia dolor amet" * 100
            topic.change_category_to_id(new_category.id)

            expect(topic.reload.title).to eq(topic_title)
            expect(topic.reload.slug).to eq(topic_slug)
          end

          it "does not save title when it is too short" do
            SiteSetting.min_topic_title_length = 15
            topic.title = "Hello world"
            expect { topic.change_category_to_id(new_category.id) }.not_to change {
              topic.reload.title
            }
          end

          it "does not save title when it is a duplicate" do
            topic_2.title = topic_title
            expect { topic_2.change_category_to_id(new_category.id) }.not_to change {
              topic_2.reload.title
            }
          end

          it "does not save title when it is blank" do
            topic.title = ""
            expect { topic.change_category_to_id(new_category.id) }.not_to change {
              topic.reload.title
            }
          end

          it "does not save title when there are too many emojis" do
            SiteSetting.max_emojis_in_title = 2

            topic.title = "Dummy topic title " + "😀" * 5
            expect { topic.change_category_to_id(new_category.id) }.not_to change {
              topic.reload.title
            }
          end
        end
      end

      context "when allow_uncategorized_topics is false" do
        before { SiteSetting.allow_uncategorized_topics = false }

        let!(:topic) { Fabricate(:topic, category: Fabricate(:category_with_definition)) }

        it "returns false" do
          expect(topic.change_category_to_id(nil)).to eq(false) # don't use "== false" here because it would also match nil
        end
      end

      describe "when the category exists" do
        before do
          topic.change_category_to_id(nil)
          category.reload
        end

        it "resets the category" do
          expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
          expect(category.topic_count).to eq(0)
        end
      end
    end
  end

  describe "scopes" do
    describe "#by_most_recently_created" do
      it "returns topics ordered by created_at desc, id desc" do
        now = Time.now
        a = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        b = Fabricate(:topic, user: user, created_at: now)
        c = Fabricate(:topic, user: user, created_at: now)
        d = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        expect(Topic.by_newest).to eq([c, b, d, a])
      end
    end

    describe "#created_since" do
      it "returns topics created after some date" do
        now = Time.now
        a = Fabricate(:topic, user: user, created_at: now - 2.minutes)
        b = Fabricate(:topic, user: user, created_at: now - 1.minute)
        c = Fabricate(:topic, user: user, created_at: now)
        d = Fabricate(:topic, user: user, created_at: now + 1.minute)
        e = Fabricate(:topic, user: user, created_at: now + 2.minutes)
        expect(Topic.created_since(now)).not_to include a
        expect(Topic.created_since(now)).not_to include b
        expect(Topic.created_since(now)).not_to include c
        expect(Topic.created_since(now)).to include d
        expect(Topic.created_since(now)).to include e
      end
    end

    describe "#visible" do
      it "returns topics set as visible" do
        a = Fabricate(:topic, user: user, visible: false)
        b = Fabricate(:topic, user: user, visible: true)
        c = Fabricate(:topic, user: user, visible: true)
        expect(Topic.visible).not_to include a
        expect(Topic.visible).to include b
        expect(Topic.visible).to include c
      end
    end

    describe "#in_category_and_subcategories" do
      it "returns topics in a category and its subcategories" do
        c1 = Fabricate(:category_with_definition)
        c2 = Fabricate(:category_with_definition, parent_category_id: c1.id)
        c3 = Fabricate(:category_with_definition)

        t1 = Fabricate(:topic, user: user, category_id: c1.id)
        t2 = Fabricate(:topic, user: user, category_id: c2.id)
        t3 = Fabricate(:topic, user: user, category_id: c3.id)

        expect(Topic.in_category_and_subcategories(c1.id)).not_to include(t3)
        expect(Topic.in_category_and_subcategories(c1.id)).to include(t2)
        expect(Topic.in_category_and_subcategories(c1.id)).to include(t1)
      end
    end
  end

  describe "#set_or_create_timer" do
    let(:topic) { Fabricate.build(:topic) }

    let(:closing_topic) { Fabricate(:topic_timer, execute_at: 5.hours.from_now).topic }

    fab!(:trust_level_4)

    it "can take a number of hours as an integer" do
      freeze_time now

      topic.set_or_create_timer(TopicTimer.types[:close], 72, by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq_time(3.days.from_now)
    end

    it "can take a number of hours as a string" do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], "18", by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq_time(18.hours.from_now)
    end

    it "can take a number of hours as a string and can handle based on last post" do
      freeze_time now
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        nil,
        by_user: admin,
        based_on_last_post: true,
        duration_minutes: "1080",
      )
      expect(topic.topic_timers.first.execute_at).to eq_time(18.hours.from_now)
    end

    it "can take a timestamp for a future time" do
      freeze_time now
      topic.set_or_create_timer(TopicTimer.types[:close], "2013-11-22 5:00", by_user: admin)
      expect(topic.topic_timers.first.execute_at).to eq_time(Time.zone.local(2013, 11, 22, 5, 0))
    end

    it "sets a validation error when given a timestamp in the past" do
      freeze_time now

      expect do
        topic.set_or_create_timer(TopicTimer.types[:close], "2013-11-19 5:00", by_user: admin)
      end.to raise_error(Discourse::InvalidParameters)
    end

    it "sets a validation error when give a timestamp of an invalid format" do
      freeze_time now

      expect do
        topic.set_or_create_timer(
          TopicTimer.types[:close],
          "۲۰۱۸-۰۳-۲۶ ۱۸:۰۰+۰۸:۰۰",
          by_user: admin,
        )
      end.to raise_error(Discourse::InvalidParameters)
    end

    it "can take a timestamp with timezone" do
      freeze_time now
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        "2013-11-25T01:35:00-08:00",
        by_user: admin,
      )
      expect(topic.topic_timers.first.execute_at).to eq_time(Time.utc(2013, 11, 25, 9, 35))
    end

    it "sets topic status update user to given user if it is a staff or TL4 user" do
      topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: admin)
      expect(topic.topic_timers.first.user).to eq(admin)
    end

    it "sets topic status update user to given user if it is a TL4 user" do
      topic.set_or_create_timer(TopicTimer.types[:close], 3, by_user: trust_level_4)
      expect(topic.topic_timers.first.user).to eq(trust_level_4)
    end

    it "sets topic status update user to system user if given user is not staff or a TL4 user" do
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        3,
        by_user: Fabricate.build(:user, id: 444),
      )
      expect(topic.topic_timers.first.user).to eq(Discourse.system_user)
    end

    it "sets topic status update user to system user if user is not given and topic creator is not staff nor TL4 user" do
      topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(topic.topic_timers.first.user).to eq(Discourse.system_user)
    end

    it "sets topic status update user to topic creator if it is a staff user" do
      staff_topic = Fabricate.build(:topic, user: Fabricate.build(:admin, id: 999))
      staff_topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(staff_topic.topic_timers.first.user_id).to eq(999)
    end

    it "sets topic status update user to topic creator if it is a TL4 user" do
      tl4_topic = Fabricate.build(:topic, user: Fabricate.build(:trust_level_4, id: 998))
      tl4_topic.set_or_create_timer(TopicTimer.types[:close], 3)
      expect(tl4_topic.topic_timers.first.user_id).to eq(998)
    end

    it "removes close topic status update if arg is nil" do
      closing_topic.set_or_create_timer(TopicTimer.types[:close], nil)
      closing_topic.reload
      expect(closing_topic.topic_timers.first).to be_nil
    end

    it "updates topic status update execute_at if it was already set to close" do
      freeze_time now
      closing_topic.set_or_create_timer(TopicTimer.types[:close], 48)
      expect(closing_topic.reload.public_topic_timer.execute_at).to eq_time(2.days.from_now)
    end

    it "should not delete topic_timer of another status_type" do
      freeze_time
      closing_topic.set_or_create_timer(TopicTimer.types[:open], nil)
      topic_timer = closing_topic.public_topic_timer

      expect(topic_timer.execute_at).to eq_time(5.hours.from_now)
      expect(topic_timer.status_type).to eq(TopicTimer.types[:close])
    end

    it "should allow status_type to be updated" do
      freeze_time

      topic_timer =
        closing_topic.set_or_create_timer(
          TopicTimer.types[:publish_to_category],
          72,
          by_user: admin,
        )

      expect(topic_timer.execute_at).to eq_time(3.days.from_now)
    end

    it "does not update topic's topic status created_at it was already set to close" do
      expect { closing_topic.set_or_create_timer(TopicTimer.types[:close], 14) }.to_not change {
        closing_topic.topic_timers.first.created_at
      }
    end

    describe "when category's default auto close is set" do
      let(:category) { Fabricate(:category_with_definition, auto_close_hours: 4) }
      let(:topic) { Fabricate(:topic, category: category) }

      it "should be able to override category's default auto close" do
        freeze_time
        Jobs.run_immediately!

        expect(topic.topic_timers.first.execute_at).to be_within_one_second_of(
          topic.created_at + 4.hours,
        )

        topic.set_or_create_timer(TopicTimer.types[:close], 2, by_user: admin)

        expect(topic.reload.closed).to eq(false)

        freeze_time 3.hours.from_now

        Jobs::TopicTimerEnqueuer.new.execute
        expect(topic.reload.closed).to eq(true)
      end
    end
  end

  describe ".for_digest" do
    context "with no edit grace period" do
      before { SiteSetting.editing_grace_period = 0 }

      it "returns none when there are no topics" do
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return category topics" do
        Fabricate(:category_with_definition, created_at: 1.minute.ago)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns regular topics" do
        topic = Fabricate(:topic, created_at: 1.minute.ago)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "doesn't return topics from muted categories" do
        category = Fabricate(:category_with_definition, created_at: 2.minutes.ago)
        Fabricate(:topic, category: category, created_at: 1.minute.ago)

        CategoryUser.set_notification_level_for_category(
          user,
          CategoryUser.notification_levels[:muted],
          category.id,
        )

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return topics that a user has muted" do
        topic = Fabricate(:topic, created_at: 1.minute.ago)

        Fabricate(
          :topic_user,
          user: user,
          topic: topic,
          notification_level: TopicUser.notification_levels[:muted],
        )

        expect(Topic.for_digest(user, 1.year.ago)).to eq([])
      end

      it "does return watched topics from muted categories" do
        category = Fabricate(:category_with_definition, created_at: 2.minutes.ago)
        topic = Fabricate(:topic, category: category, created_at: 1.minute.ago)

        CategoryUser.set_notification_level_for_category(
          user,
          CategoryUser.notification_levels[:muted],
          category.id,
        )
        Fabricate(
          :topic_user,
          user: user,
          topic: topic,
          notification_level: TopicUser.notification_levels[:regular],
        )

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "doesn't return topics from suppressed categories" do
        category = Fabricate(:category_with_definition, created_at: 2.minutes.ago)
        topic = Fabricate(:topic, category: category, created_at: 1.minute.ago)

        SiteSetting.digest_suppress_categories = "#{category.id}"

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank

        Fabricate(
          :topic_user,
          user: user,
          topic: topic,
          notification_level: TopicUser.notification_levels[:regular],
        )

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "doesn't return topics with a suppressed tag" do
        topic_with_tags = Fabricate(:topic, created_at: 1.minute.ago)
        topic_without_tags = Fabricate(:topic, created_at: 1.minute.ago)
        topic_with_other_tags = Fabricate(:topic, created_at: 1.minute.ago)

        tag_1 = Fabricate(:tag)
        tag_2 = Fabricate(:tag)
        tag_3 = Fabricate(:tag)

        Fabricate(:topic_tag, topic: topic_with_tags, tag: tag_1)
        Fabricate(:topic_tag, topic: topic_with_tags, tag: tag_2)

        Fabricate(:topic_tag, topic: topic_with_other_tags, tag: tag_2)
        Fabricate(:topic_tag, topic: topic_with_other_tags, tag: tag_3)

        SiteSetting.digest_suppress_tags = "#{tag_1.name}"

        topics = Topic.for_digest(user, 1.year.ago, top_order: true)

        expect(topics).to contain_exactly(topic_without_tags, topic_with_other_tags)

        Fabricate(
          :topic_user,
          user: user,
          topic: topic_with_tags,
          notification_level: TopicUser.notification_levels[:regular],
        )

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to contain_exactly(
          topic_without_tags,
          topic_with_other_tags,
        )
      end

      it "doesn't return topics from TL0 users" do
        new_user = Fabricate(:user, trust_level: 0)
        Fabricate(:topic, user: new_user, created_at: 1.minute.ago)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns topics from TL0 users if given include_tl0" do
        new_user = Fabricate(:user, trust_level: 0)
        topic = Fabricate(:topic, user_id: new_user.id, created_at: 1.minute.ago)

        expect(Topic.for_digest(user, 1.year.ago, top_order: true, include_tl0: true)).to eq(
          [topic],
        )
      end

      it "returns topics from TL0 users if enabled in preferences" do
        new_user = Fabricate(:user, trust_level: 0)
        topic = Fabricate(:topic, user: new_user, created_at: 1.minute.ago)

        u = Fabricate(:user)
        u.user_option.include_tl0_in_digests = true

        expect(Topic.for_digest(u, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "doesn't return topics with only muted tags" do
        tag = Fabricate(:tag)
        TagUser.change(user.id, tag.id, TagUser.notification_levels[:muted])
        Fabricate(:topic, tags: [tag], created_at: 1.minute.ago)

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to be_blank
      end

      it "returns topics with both muted and not muted tags" do
        muted_tag, other_tag = Fabricate(:tag), Fabricate(:tag)
        TagUser.change(user.id, muted_tag.id, TagUser.notification_levels[:muted])
        topic = Fabricate(:topic, tags: [muted_tag, other_tag], created_at: 1.minute.ago)

        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic])
      end

      it "returns topics with no tags too" do
        muted_tag = Fabricate(:tag)
        TagUser.change(user.id, muted_tag.id, TagUser.notification_levels[:muted])
        _topic1 = Fabricate(:topic, tags: [muted_tag], created_at: 1.minute.ago)
        topic2 =
          Fabricate(:topic, tags: [Fabricate(:tag), Fabricate(:tag)], created_at: 1.minute.ago)
        topic3 = Fabricate(:topic, created_at: 1.minute.ago)
        topics = Topic.for_digest(user, 1.year.ago, top_order: true)

        expect(topics.size).to eq(2)
        expect(topics).to contain_exactly(topic2, topic3)
      end

      it "sorts by category notification levels" do
        category1, category2 =
          Fabricate(:category_with_definition),
          Fabricate(:category_with_definition, created_at: 2.minutes.ago)
        2.times { |i| Fabricate(:topic, category: category1, created_at: 1.minute.ago) }
        topic1 = Fabricate(:topic, category: category2, created_at: 1.minute.ago)
        2.times { |i| Fabricate(:topic, category: category1, created_at: 1.minute.ago) }
        CategoryUser.create(
          user: user,
          category: category2,
          notification_level: CategoryUser.notification_levels[:watching],
        )
        for_digest = Topic.for_digest(user, 1.year.ago, top_order: true)

        expect(for_digest.first).to eq(topic1)
      end

      it "sorts by topic notification levels" do
        topics = []
        3.times { |i| topics << Fabricate(:topic, created_at: 1.minute.ago) }
        TopicUser.create(
          user_id: user.id,
          topic_id: topics[0].id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        TopicUser.create(
          user_id: user.id,
          topic_id: topics[2].id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        for_digest = Topic.for_digest(user, 1.year.ago, top_order: true).pluck(:id)

        expect(for_digest).to eq([topics[2].id, topics[0].id, topics[1].id])
      end
    end

    context "with editing_grace_period" do
      before { SiteSetting.editing_grace_period = 5.minutes }

      it "excludes topics that are within the grace period" do
        topic1 = Fabricate(:topic, created_at: 6.minutes.ago)
        _topic2 = Fabricate(:topic, created_at: 4.minutes.ago)
        expect(Topic.for_digest(user, 1.year.ago, top_order: true)).to eq([topic1])
      end
    end
  end

  describe ".secured" do
    it "should return the right topics" do
      category = Fabricate(:category_with_definition, read_restricted: true)
      topic = Fabricate(:topic, category: category, created_at: 1.day.ago)
      group.add(user)
      private_category = Fabricate(:private_category_with_definition, group: group)

      expect(Topic.secured(Guardian.new(nil))).to eq([])

      expect(Topic.secured(Guardian.new(user))).to contain_exactly(private_category.topic)

      expect(Topic.secured(Guardian.new(Fabricate(:admin)))).to contain_exactly(
        category.topic,
        private_category.topic,
        topic,
      )
    end
  end

  describe "all_allowed_users" do
    fab!(:topic) { Fabricate(:topic, allowed_groups: [group]) }
    fab!(:allowed_user, :user)
    fab!(:allowed_group_user, :user)
    fab!(:moderator) { Fabricate(:user, moderator: true) }
    fab!(:rando, :user)

    before do
      topic.allowed_users << allowed_user
      group.users << allowed_group_user
    end

    it "includes allowed_users" do
      expect(topic.all_allowed_users).to include allowed_user
    end

    it "includes allowed_group_users" do
      expect(topic.all_allowed_users).to include allowed_group_user
    end

    it "includes moderators if flagged and a pm" do
      topic.stubs(:has_flags?).returns(true)
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).to include moderator
    end

    it "includes moderators if official warning" do
      topic.stubs(:subtype).returns(TopicSubtype.moderator_warning)
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).to include moderator
    end

    it "does not include moderators if pm without flags" do
      topic.stubs(:private_message?).returns(true)
      expect(topic.all_allowed_users).not_to include moderator
    end

    it "does not include moderators for regular topic" do
      expect(topic.all_allowed_users).not_to include moderator
    end

    it "does not include randos" do
      expect(topic.all_allowed_users).not_to include rando
    end
  end

  describe "#listable_count_per_day" do
    before(:each) do
      freeze_time_safe

      Fabricate(:topic)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:topic, created_at: 2.days.ago)
      Fabricate(:topic, created_at: 4.days.ago)
    end

    let(:listable_topics_count_per_day) do
      { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1 }
    end

    it "collect closed interval listable topics count" do
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).to include(
        listable_topics_count_per_day,
      )
      expect(Topic.listable_count_per_day(2.days.ago, Time.now)).not_to include(
        4.days.ago.to_date => 1,
      )
    end

    it "returns the correct count with group filter" do
      group = Fabricate(:group)
      group.add(user)
      topic = Fabricate(:topic, user: user)

      expect(Topic.listable_count_per_day(2.days.ago, Time.now, nil, false, [group.id])).to include(
        Time.now.utc.to_date => 1,
      )
    end
  end

  describe "#read_restricted_category?" do
    let(:category) { Category.new }

    it "is true if the category is secure" do
      category.stubs(:read_restricted).returns(true)
      expect(Topic.new(category: category).read_restricted_category?).to eq(true)
    end

    it "is false if the category is not secure" do
      category.stubs(:read_restricted).returns(false)
      expect(Topic.new(category: category).read_restricted_category?).to eq(false)
    end

    it "is falsey if there is no category" do
      expect(Topic.new(category: nil).read_restricted_category?).to eq(nil)
    end
  end

  describe "trash!" do
    fab!(:topic)

    context "with category's topic count" do
      fab!(:category, :category_with_definition)

      it "subtracts 1 if topic is being deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.trash!(moderator) }.to change { category.reload.topic_count }.by(-1)
      end

      it "doesn't subtract 1 if topic is already deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.trash!(moderator) }.to_not change { category.reload.topic_count }
      end

      it "doesn't subtract 1 if topic is unlisted" do
        topic = Fabricate(:topic, category: category, visible: false)
        expect { topic.trash!(moderator) }.to_not change { category.reload.topic_count }
      end
    end

    it "trashes topic embed record" do
      post = Fabricate(:post, topic: topic, post_number: 1)
      topic_embed =
        TopicEmbed.create!(
          topic_id: topic.id,
          embed_url: "https://blog.codinghorror.com/password-rules-are-bullshit",
          post_id: post.id,
        )
      topic.trash!
      topic_embed.reload
      expect(topic_embed.deleted_at).not_to eq(nil)
    end

    it "triggers the topic trashed event" do
      events = DiscourseEvent.track_events(:topic_trashed) { topic.trash! }

      expect(events.size).to eq(1)
    end

    it "does not trigger the topic trashed event when topic is already trashed" do
      topic.trash!

      events = DiscourseEvent.track_events(:topic_trashed) { topic.trash! }

      expect(events.size).to eq(0)
    end
  end

  describe "recover!" do
    fab!(:topic)

    context "with category's topic count" do
      fab!(:category, :category_with_definition)

      it "adds 1 if topic is deleted" do
        topic = Fabricate(:topic, category: category, deleted_at: 1.day.ago)
        expect { topic.recover! }.to change { category.reload.topic_count }.by(1)
      end

      it "doesn't add 1 if topic is not deleted" do
        topic = Fabricate(:topic, category: category)
        expect { topic.recover! }.to_not change { category.reload.topic_count }
      end

      it "doesn't add 1 if topic is not visible" do
        topic = Fabricate(:topic, category: category, visible: false)
        expect { topic.recover! }.to_not change { category.reload.topic_count }
      end
    end

    it "recovers topic embed record" do
      topic = Fabricate(:topic, deleted_at: 1.day.ago)
      post = Fabricate(:post, topic: topic, post_number: 1)
      topic_embed =
        TopicEmbed.create!(
          topic_id: topic.id,
          embed_url: "https://blog.codinghorror.com/password-rules-are-bullshit",
          post_id: post.id,
          deleted_at: 1.day.ago,
        )
      topic.recover!
      topic_embed.reload
      expect(topic_embed.deleted_at).to be_nil
    end

    it "triggers the topic recovered event" do
      topic.trash!

      events = DiscourseEvent.track_events(:topic_recovered) { topic.recover! }

      expect(events.size).to eq(1)
    end

    it "does not trigger the topic recovered event when topic is already recovered" do
      topic.trash!
      topic.recover!

      events = DiscourseEvent.track_events(:topic_recovered) { topic.recover! }

      expect(events.size).to eq(0)
    end
  end

  describe "new user limits" do
    before do
      SiteSetting.max_topics_in_first_day = 1
      SiteSetting.max_replies_in_first_day = 1
      SiteSetting.stubs(:client_settings_json).returns(SiteSetting.client_settings_json_uncached)
      RateLimiter.stubs(:rate_limit_create_topic).returns(100)
      RateLimiter.enable
    end

    it "limits new users to max_topics_in_first_day and max_posts_in_first_day" do
      start = Time.now.tomorrow.beginning_of_day

      freeze_time(start)

      user = Fabricate(:user, refresh_auto_groups: true)
      topic_id = create_post(user: user).topic_id

      freeze_time(start + 10.minutes)
      expect { create_post(user: user) }.to raise_error(RateLimiter::LimitExceeded)

      freeze_time(start + 20.minutes)
      create_post(user: user, topic_id: topic_id)

      freeze_time(start + 30.minutes)
      expect { create_post(user: user, topic_id: topic_id) }.to raise_error(
        RateLimiter::LimitExceeded,
      )
    end

    it "starts counting when they make their first post/topic" do
      start = Time.now.tomorrow.beginning_of_day

      freeze_time(start)

      user = Fabricate(:user, refresh_auto_groups: true)

      freeze_time(start + 25.hours)
      topic_id = create_post(user: user).topic_id

      freeze_time(start + 26.hours)
      expect { create_post(user: user) }.to raise_error(RateLimiter::LimitExceeded)

      freeze_time(start + 27.hours)
      create_post(user: user, topic_id: topic_id)

      freeze_time(start + 28.hours)
      expect { create_post(user: user, topic_id: topic_id) }.to raise_error(
        RateLimiter::LimitExceeded,
      )
    end
  end

  describe "per day personal message limit" do
    before do
      SiteSetting.max_personal_messages_per_day = 1
      SiteSetting.max_topics_per_day = 0
      SiteSetting.max_topics_in_first_day = 0
      RateLimiter.enable
    end

    it "limits according to max_personal_messages_per_day" do
      create_post(
        user: user,
        archetype: "private_message",
        target_usernames: [user1.username, user2.username],
      )
      expect {
        create_post(
          user: user,
          archetype: "private_message",
          target_usernames: [user1.username, user2.username],
        )
      }.to raise_error(RateLimiter::LimitExceeded)
    end
  end

  describe ".count_exceeds_minimum?" do
    before { SiteSetting.minimum_topics_similar = 20 }

    context "when Topic count is greater than minimum_topics_similar" do
      it "should be true" do
        Topic.stubs(:count).returns(30)
        expect(Topic.count_exceeds_minimum?).to be_truthy
      end
    end

    context "when topic's count is less than minimum_topics_similar" do
      it "should be false" do
        Topic.stubs(:count).returns(10)
        expect(Topic.count_exceeds_minimum?).to_not be_truthy
      end
    end
  end

  describe "expandable_first_post?" do
    let(:topic) { Fabricate.build(:topic) }

    it "is false if embeddable_host is blank" do
      expect(topic.expandable_first_post?).to eq(false)
    end

    describe "with an embeddable host" do
      before do
        Fabricate(:embeddable_host)
        SiteSetting.embed_truncate = true
        topic.stubs(:has_topic_embed?).returns(true)
      end

      it "is true with the correct settings and topic_embed" do
        expect(topic.expandable_first_post?).to eq(true)
      end
      it "is false if embed_truncate? is false" do
        SiteSetting.embed_truncate = false
        expect(topic.expandable_first_post?).to eq(false)
      end

      it "is false if has_topic_embed? is false" do
        topic.stubs(:has_topic_embed?).returns(false)
        expect(topic.expandable_first_post?).to eq(false)
      end
    end
  end

  it "has custom fields" do
    topic = Fabricate(:topic)
    expect(topic.custom_fields["a"]).to eq(nil)

    topic.custom_fields["bob"] = "marley"
    topic.custom_fields["jack"] = "black"
    topic.save

    topic = Topic.find(topic.id)
    expect(topic.custom_fields).to eq("bob" => "marley", "jack" => "black")
  end

  it "doesn't validate the title again if it isn't changing" do
    SiteSetting.min_topic_title_length = 5
    topic = Fabricate(:topic, title: "Short")
    expect(topic).to be_valid

    SiteSetting.min_topic_title_length = 15
    topic.last_posted_at = 1.minute.ago
    expect(topic.save).to eq(true)
  end

  it "Correctly sets #message_archived?" do
    topic = Fabricate(:private_message_topic)
    user = topic.user

    expect(topic.message_archived?(user)).to eq(false)

    group2 = Fabricate(:group)

    group.add(user)

    TopicAllowedGroup.create!(topic_id: topic.id, group_id: group.id)
    TopicAllowedGroup.create!(topic_id: topic.id, group_id: group2.id)
    GroupArchivedMessage.create!(topic_id: topic.id, group_id: group.id)

    expect(topic.message_archived?(user)).to eq(true)

    # here is a pickle, we add another group, make the user a
    # member of that new group... now this message is not properly archived
    # for the user any more
    group2.add(user)
    expect(topic.message_archived?(user)).to eq(false)
  end

  it "will trigger :topic_status_updated" do
    topic = Fabricate(:topic)
    user = topic.user
    user.admin = true
    topic_status_event = spy

    blk = Proc.new { topic_status_event.triggered }

    DiscourseEvent.on(:topic_status_updated, &blk)

    topic.update_status("closed", true, user)
    topic.reload

    expect(topic_status_event).to have_received(:triggered)
  ensure
    DiscourseEvent.off(:topic_status_updated, &blk)
  end

  it "allows users to normalize counts" do
    topic = Fabricate(:topic, last_posted_at: 1.year.ago)
    post1 = Fabricate(:post, topic: topic, post_number: 1)
    post2 = Fabricate(:post, topic: topic, post_type: Post.types[:whisper], post_number: 2)

    Topic.reset_all_highest!
    topic.reload

    expect(topic.posts_count).to eq(1)
    expect(topic.word_count).to eq(post1.word_count)
    expect(topic.highest_post_number).to eq(post1.post_number)
    expect(topic.highest_staff_post_number).to eq(post2.post_number)
    expect(topic.last_posted_at).to eq_time(post1.created_at)
  end

  describe "featured link" do
    before { SiteSetting.topic_featured_link_enabled = true }
    fab!(:topic)

    it "can validate featured link" do
      topic.featured_link = " invalid string"

      expect(topic).not_to be_valid
      expect(topic.errors[:featured_link]).to be_present
    end

    it "can properly save the featured link" do
      topic.featured_link = "  https://github.com/discourse/discourse"

      expect(topic.save).to be_truthy
      expect(topic.featured_link).to eq("https://github.com/discourse/discourse")
    end

    context "when category restricts present" do
      let!(:link_category) { Fabricate(:link_category) }
      let(:link_topic) { Fabricate(:topic, category: link_category) }

      it "can save the featured link if it belongs to that category" do
        link_topic.featured_link = "https://github.com/discourse/discourse"
        expect(link_topic.save).to be_truthy
        expect(link_topic.featured_link).to eq("https://github.com/discourse/discourse")
      end

      it "can not save the featured link if category does not allow it" do
        topic.category = Fabricate(:category_with_definition, topic_featured_link_allowed: false)
        topic.featured_link = "https://github.com/discourse/discourse"
        expect(topic.save).to be_falsey
      end

      it "if category changes to disallow it, topic remains valid" do
        t =
          Fabricate(
            :topic,
            category: link_category,
            featured_link: "https://github.com/discourse/discourse",
          )

        link_category.topic_featured_link_allowed = false
        link_category.save!
        t.reload

        expect(t.valid?).to eq(true)
      end
    end
  end

  describe "#time_to_first_response" do
    it "should have no results if no topics in range" do
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
    end

    it "should have no results if there is only a topic with no replies" do
      topic = Fabricate(:topic, created_at: 1.hour.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1)
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.time_to_first_response_total).to eq(0)
    end

    it "should have no results if reply is from first poster" do
      topic = Fabricate(:topic, created_at: 1.hour.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 2)
      expect(Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.time_to_first_response_total).to eq(0)
    end

    it "should have results if there's a topic with replies" do
      topic = Fabricate(:topic, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, post_number: 2, created_at: 2.hours.ago)
      r = Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now)
      expect(r.count).to eq(1)
      expect(r[0]["hours"].to_f.round).to eq(1)
      expect(Topic.time_to_first_response_total).to eq(1)
    end

    it "should have results if there's a topic with replies" do
      SiteSetting.max_category_nesting = 3

      category = Fabricate(:category_with_definition)
      subcategory = Fabricate(:category_with_definition, parent_category_id: category.id)
      subsubcategory = Fabricate(:category_with_definition, parent_category_id: subcategory.id)

      topic = Fabricate(:topic, category: subsubcategory, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 3.hours.ago)
      Fabricate(:post, topic: topic, post_number: 2, created_at: 2.hours.ago)

      expect(
        Topic.time_to_first_response_total(category_id: category.id, include_subcategories: true),
      ).to eq(1)
    end

    it "should only count regular posts as the first response" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(
        :post,
        topic: topic,
        post_number: 2,
        created_at: 4.hours.ago,
        post_type: Post.types[:whisper],
      )
      Fabricate(
        :post,
        topic: topic,
        post_number: 3,
        created_at: 3.hours.ago,
        post_type: Post.types[:moderator_action],
      )
      Fabricate(
        :post,
        topic: topic,
        post_number: 4,
        created_at: 2.hours.ago,
        post_type: Post.types[:small_action],
      )
      Fabricate(:post, topic: topic, post_number: 5, created_at: 1.hour.ago)
      r = Topic.time_to_first_response_per_day(5.days.ago, Time.zone.now)
      expect(r.count).to eq(1)
      expect(r[0]["hours"].to_f.round).to eq(4)
      expect(Topic.time_to_first_response_total).to eq(4)
    end
  end

  describe "#with_no_response" do
    it "returns nothing with no topics" do
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
    end

    it "returns 1 with one topic that has no replies" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 1 with one topic that has no replies and author was changed on first post" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(
        :post,
        topic: topic,
        user: Fabricate(:user),
        post_number: 1,
        created_at: 5.hours.ago,
      )
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 1 with one topic that has a reply by the first poster" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 2, created_at: 2.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end

    it "returns 0 with a topic with 1 reply" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      _post1 =
        Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      _post2 = Fabricate(:post, topic: topic, post_number: 2, created_at: 2.hours.ago)
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(0)
      expect(Topic.with_no_response_total).to eq(0)
    end

    it "returns 1 with one topic that doesn't have regular replies" do
      topic = Fabricate(:topic, created_at: 5.hours.ago)
      Fabricate(:post, topic: topic, user: topic.user, post_number: 1, created_at: 5.hours.ago)
      Fabricate(
        :post,
        topic: topic,
        post_number: 2,
        created_at: 4.hours.ago,
        post_type: Post.types[:whisper],
      )
      Fabricate(
        :post,
        topic: topic,
        post_number: 3,
        created_at: 3.hours.ago,
        post_type: Post.types[:moderator_action],
      )
      Fabricate(
        :post,
        topic: topic,
        post_number: 4,
        created_at: 2.hours.ago,
        post_type: Post.types[:small_action],
      )
      expect(Topic.with_no_response_per_day(5.days.ago, Time.zone.now).count).to eq(1)
      expect(Topic.with_no_response_total).to eq(1)
    end
  end

  describe "#pm_with_non_human_user?" do
    fab!(:robot, :bot)

    fab!(:topic) do
      topic =
        Fabricate(
          :private_message_topic,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: robot),
            Fabricate.build(:topic_allowed_user, user: user),
          ],
        )

      Fabricate(:post, topic: topic)
      topic
    end

    describe "when PM is between a human and a non human user" do
      it "should return true" do
        expect(topic.pm_with_non_human_user?).to be(true)
      end
    end

    describe "when PM contains 2 human users and a non human user" do
      it "should return false" do
        Fabricate(:topic_allowed_user, topic: topic, user: Fabricate(:user))

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end

    describe "when PM only contains a user" do
      it "should return true" do
        topic.topic_allowed_users.first.destroy!

        expect(topic.reload.pm_with_non_human_user?).to be(true)
      end
    end

    describe "when PM contains a group" do
      it "should return false" do
        Fabricate(:topic_allowed_group, topic: topic)

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end

    describe "when topic is not a PM" do
      it "should return false" do
        topic.convert_to_public_topic(Fabricate(:admin))

        expect(topic.pm_with_non_human_user?).to be(false)
      end
    end
  end

  describe "#remove_allowed_user" do
    fab!(:topic)
    fab!(:private_topic) do
      Fabricate(
        :private_message_topic,
        title: "Private message",
        user: admin,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: admin),
          Fabricate.build(:topic_allowed_user, user: user1),
        ],
      )
    end

    describe "removing oneself" do
      it "should remove oneself" do
        topic.allowed_users << user1

        expect(topic.remove_allowed_user(user1, user1)).to eq(true)
        expect(topic.allowed_users.include?(user1)).to eq(false)

        post = Post.last

        expect(post.user).to eq(user1)
        expect(post.post_type).to eq(Post.types[:small_action])
        expect(post.action_code).to eq("user_left")
      end

      it "should show a small action when user removes themselves from pm" do
        expect do private_topic.remove_allowed_user(user1, user1) end.to change {
          private_topic.posts.where(action_code: "user_left").count
        }.by(1)
      end
    end
  end

  describe "#featured_link_root_domain" do
    let(:topic) { Fabricate.build(:topic) }

    %w[
      https://meta.discourse.org
      https://meta.discourse.org/
      https://meta.discourse.org/?filter=test
      https://meta.discourse.org/t/中國/1
    ].each do |featured_link|
      it "should extract the root domain from #{featured_link} correctly" do
        topic.featured_link = featured_link
        expect(topic.featured_link_root_domain).to eq("discourse.org")
      end
    end
  end

  describe "#reset_bumped_at" do
    it "ignores hidden, deleted, moderator and small action posts when resetting the topic's bump date" do
      post1 = create_post(created_at: 10.hours.ago)
      topic = post1.topic

      expect { topic.reset_bumped_at }.to_not change { topic.bumped_at }

      post2 = Fabricate(:post, topic: topic, post_number: 2, created_at: 9.hours.ago)
      Fabricate(
        :post,
        topic: topic,
        post_number: 3,
        created_at: 8.hours.ago,
        deleted_at: 1.hour.ago,
      )
      Fabricate(:post, topic: topic, post_number: 4, created_at: 7.hours.ago, hidden: true)
      Fabricate(:post, topic: topic, post_number: 5, created_at: 6.hours.ago, user_deleted: true)
      Fabricate(
        :post,
        topic: topic,
        post_number: 6,
        created_at: 5.hours.ago,
        post_type: Post.types[:whisper],
      )

      expect { topic.reset_bumped_at }.to change { topic.bumped_at }.to(post2.reload.created_at)

      post3 =
        Fabricate(
          :post,
          topic: topic,
          post_number: 7,
          created_at: 4.hours.ago,
          post_type: Post.types[:regular],
        )
      expect { topic.reset_bumped_at }.to change { topic.bumped_at }.to(post3.reload.created_at)

      Fabricate(
        :post,
        topic: topic,
        post_number: 8,
        created_at: 3.hours.ago,
        post_type: Post.types[:small_action],
      )
      Fabricate(
        :post,
        topic: topic,
        post_number: 9,
        created_at: 2.hours.ago,
        post_type: Post.types[:moderator_action],
      )
      expect { topic.reset_bumped_at }.not_to change { topic.bumped_at }
    end
  end

  describe "#access_topic_via_group" do
    let(:open_group) { Fabricate(:group, public_admission: true) }
    let(:request_group) do
      Fabricate(:group).tap do |g|
        g.add_owner(user)
        g.allow_membership_requests = true
        g.save!
      end
    end
    let(:category) { Fabricate(:category_with_definition) }
    let(:topic) { Fabricate(:topic, category: category) }

    it "returns a group that is open or accepts membership requests and has access to the topic" do
      expect(topic.access_topic_via_group).to eq(nil)

      category.set_permissions(request_group => :full)
      category.save!

      expect(topic.access_topic_via_group).to eq(request_group)

      category.set_permissions(request_group => :full, open_group => :full)
      category.save!

      expect(topic.access_topic_via_group).to eq(open_group)
    end
  end

  describe "#before_save" do
    it "replaces empty locales with nil" do
      topic = Fabricate(:topic, locale: "en")

      topic.locale = ""
      topic.save!

      expect(topic.reload.locale).to eq(nil)
    end
  end

  describe "#after_update" do
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:category) { Fabricate(:category_with_definition, read_restricted: true) }

    it "removes the topic as featured from user profiles if new category is read_restricted" do
      user.user_profile.update(featured_topic: topic)
      expect(user.user_profile.featured_topic).to eq(topic)

      topic.update(category: category)
      expect(user.user_profile.reload.featured_topic).to eq(nil)
    end
  end

  describe "#auto_close_threshold_reached?" do
    fab!(:post)
    fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: post, topic: post.topic) }

    let(:topic) { post.topic }

    before do
      Reviewable.set_priorities(low: 2.0, medium: 6.0, high: 9.0)
      SiteSetting.num_flaggers_to_close_topic = 2
      SiteSetting.reviewable_default_visibility = "medium"
      SiteSetting.auto_close_topic_sensitivity = Reviewable.sensitivities[:high]
    end

    it "ignores flags with a low score" do
      5.times do
        reviewable.add_score(
          Fabricate(:user, trust_level: TrustLevel[0]),
          PostActionType.types[:spam],
          created_at: 1.minute.ago,
        )
      end

      expect(topic.auto_close_threshold_reached?).to eq(false)
    end

    it "returns true when the flags have a high score" do
      5.times do
        reviewable.add_score(
          Fabricate(:user, admin: true),
          PostActionType.types[:spam],
          created_at: 1.minute.ago,
        )
      end

      expect(topic.auto_close_threshold_reached?).to eq(true)
    end
  end

  describe "#update_action_counts" do
    let(:topic) { Fabricate(:topic) }

    it "updates like count without including whisper posts" do
      post = Fabricate(:post, topic: topic)
      whisper_post = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])

      topic.update_action_counts
      expect(topic.like_count).to eq(0)

      PostAction.create!(post: post, user: user, post_action_type_id: PostActionType.types[:like])

      topic.update_action_counts
      expect(topic.like_count).to eq(1)

      PostAction.create!(
        post: whisper_post,
        user: user,
        post_action_type_id: PostActionType.types[:like],
      )

      topic.update_action_counts
      expect(topic.like_count).to eq(1)
    end
  end

  describe "#incoming_email_addresses" do
    fab!(:group) do
      Fabricate(
        :group,
        smtp_server: "imap.gmail.com",
        smtp_port: 587,
        email_username: "discourse@example.com",
        email_password: "discourse@example.com",
      )
    end

    fab!(:topic) do
      Fabricate(
        :private_message_topic,
        topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: group)],
      )
    end

    let!(:incoming1) do
      Fabricate(
        :incoming_email,
        to_addresses: "discourse@example.com",
        from_address: "johnsmith@user.com",
        topic: topic,
        post: topic.posts.first,
        created_at: 20.minutes.ago,
      )
    end
    let!(:incoming2) do
      Fabricate(
        :incoming_email,
        from_address: "discourse@example.com",
        to_addresses: "johnsmith@user.com",
        topic: topic,
        post: Fabricate(:post, topic: topic),
        created_at: 10.minutes.ago,
      )
    end
    let!(:incoming3) do
      Fabricate(
        :incoming_email,
        to_addresses: "discourse@example.com",
        from_address: "johnsmith@user.com",
        topic: topic,
        post: topic.posts.first,
        cc_addresses: "otherguy@user.com",
        created_at: 2.minutes.ago,
      )
    end
    let!(:incoming4) do
      Fabricate(
        :incoming_email,
        to_addresses: "unrelated@test.com",
        from_address: "discourse@example.com",
        topic: topic,
        post: topic.posts.first,
        created_at: 1.minutes.ago,
      )
    end

    it "returns an array of all the incoming email addresses" do
      expect(topic.incoming_email_addresses).to match_array(
        %w[discourse@example.com johnsmith@user.com otherguy@user.com unrelated@test.com],
      )
    end

    it "returns an array of all the incoming email addresses where incoming was received before X" do
      expect(topic.incoming_email_addresses(received_before: 5.minutes.ago)).to match_array(
        %w[discourse@example.com johnsmith@user.com],
      )
    end

    context "when the group is present" do
      it "excludes incoming emails that are not to or CCd to the group" do
        expect(topic.incoming_email_addresses(group: group)).not_to include("unrelated@test.com")
      end
    end
  end

  describe "#cannot_permanently_delete_reason" do
    fab!(:post)
    let!(:topic) { post.topic }

    before { freeze_time }

    it "returns error message if topic has more posts" do
      post_2 = create_post(user: user, topic_id: topic.id, raw: "some post content")

      PostDestroyer.new(admin, post).destroy
      expect(topic.reload.cannot_permanently_delete_reason(Fabricate(:admin))).to eq(
        I18n.t("post.cannot_permanently_delete.many_posts"),
      )

      PostDestroyer.new(admin, post_2.reload).destroy
      expect(topic.reload.cannot_permanently_delete_reason(Fabricate(:admin))).to eq(
        I18n.t("post.cannot_permanently_delete.many_posts"),
      )

      PostDestroyer.new(admin, post_2.reload, force_destroy: true).destroy
      expect(topic.reload.cannot_permanently_delete_reason(Fabricate(:admin))).to eq(nil)
    end

    it "returns error message if same admin and time did not pass" do
      PostDestroyer.new(admin, post).destroy
      expect(topic.reload.cannot_permanently_delete_reason(admin)).to eq(
        I18n.t(
          "post.cannot_permanently_delete.wait_or_different_admin",
          time_left: RateLimiter.time_left(Post::PERMANENT_DELETE_TIMER.to_i),
        ),
      )
    end

    it "returns nothing if different admin" do
      PostDestroyer.new(admin, post).destroy
      expect(topic.reload.cannot_permanently_delete_reason(Fabricate(:admin))).to eq(nil)
    end
  end

  describe "#publish_stats_to_clients!" do
    fab!(:user1, :user)
    fab!(:user2, :user)
    fab!(:topic) { Fabricate(:topic, user: user1) }
    fab!(:post1) { Fabricate(:post, topic: topic, user: user1) }
    fab!(:post2) { Fabricate(:post, topic: topic, user: user2) }
    fab!(:like1) { Fabricate(:like, post: post1, user: user2) }

    it "it is triggered when a post publishes a message of type :liked or :unliked" do
      %i[liked unliked].each do |action|
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            post1.publish_change_to_clients!(action)
          end

        stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
        expect(stats_message).to be_present
        expect(stats_message.data[:like_count]).to eq(topic.like_count)
      end
    end

    it "it is triggered when a post publishes a message of type :created, :destroyed, :deleted, :recovered" do
      freeze_time Date.today

      %i[created destroyed deleted recovered].each do |action|
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            post1.publish_change_to_clients!(action)
          end

        stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
        expect(stats_message).to be_present
        expect(stats_message.data[:posts_count]).to eq(topic.posts_count)
        expect(stats_message.data[:last_posted_at]).to eq(topic.last_posted_at.as_json)
        expect(stats_message.data[:last_poster]).to eq(
          BasicUserSerializer.new(topic.last_poster, root: false).as_json,
        )
      end
    end

    it "it is not triggered when a post publishes an unhandled kind of message" do
      %i[unhandled unknown dont_care].each do |action|
        messages =
          MessageBus.track_publish("/topic/#{topic.id}") do
            post1.publish_change_to_clients!(action)
          end

        stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
        expect(stats_message).to be_blank
      end
    end
  end

  describe "#group_pm?" do
    context "when topic is not a private message" do
      subject(:public_topic) { Fabricate(:topic) }

      it { is_expected.not_to be_a_group_pm }
    end

    context "when topic is a private message" do
      subject(:pm_topic) { Fabricate(:private_message_topic) }

      context "when more than two people have access" do
        let(:other_user) { Fabricate(:user) }

        before { pm_topic.allowed_users << other_user }

        it { is_expected.to be_a_group_pm }
      end

      context "when no more than two people have access" do
        it { is_expected.not_to be_a_group_pm }
      end
    end
  end

  describe "#has_localization?" do
    it "returns true if the topic has localization" do
      topic = Fabricate(:topic)
      Fabricate(:topic_localization, topic: topic, locale: "zh_CN")

      expect(topic.has_localization?(:zh_CN)).to eq(true)
      expect(topic.has_localization?(:"zh_CN")).to eq(true)
      expect(topic.has_localization?("zh-CN")).to eq(true)

      expect(topic.has_localization?("z")).to eq(false)
    end
  end

  describe "#get_localization" do
    it "returns the localization with the specified locale" do
      I18n.locale = "ja"
      topic = Fabricate(:topic)
      zh_localization = Fabricate(:topic_localization, topic:, locale: "zh_CN")
      ja_localization = Fabricate(:topic_localization, topic:, locale: "ja")

      expect(topic.get_localization(:zh_CN)).to eq(zh_localization)
      expect(topic.get_localization("zh-CN")).to eq(zh_localization)
      expect(topic.get_localization("xx")).to eq(nil)
      expect(topic.get_localization).to eq(ja_localization)
    end

    it "returns a regional localization (ja_JP) when the user's locale (ja) is not available" do
      I18n.locale = "ja"
      topic = Fabricate(:topic)
      ja_jp_localization = Fabricate(:topic_localization, topic:, locale: "ja_JP")

      expect(topic.get_localization).to eq(ja_jp_localization)
    end

    it "returns a normalized localization (pt) if the user's locale (pt_BR) is not available" do
      I18n.locale = "pt_BR"
      topic = Fabricate(:topic)
      pt_localization = Fabricate(:topic_localization, topic:, locale: "pt")

      expect(topic.get_localization).to eq(pt_localization)
    end
  end

  describe "#in_user_locale?" do
    it "returns true if the topic has localization in the user's locale" do
      I18n.locale = "ja"
      topic = Fabricate(:topic, locale: "ja")

      expect(topic.in_user_locale?).to eq(true)

      topic.update!(locale: "ja_JP")
      expect(topic.in_user_locale?).to eq(true)

      topic.update!(locale: "es")
      expect(topic.in_user_locale?).to eq(false)
    end
  end
end
