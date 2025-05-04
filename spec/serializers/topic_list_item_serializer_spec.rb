# frozen_string_literal: true

RSpec.describe TopicListItemSerializer do
  let(:topic) do
    date = Time.zone.now

    Fabricate(
      :topic,
      title: "This is a test topic title",
      created_at: date - 2.minutes,
      bumped_at: date,
    )
  end

  it "correctly serializes topic" do
    SiteSetting.topic_featured_link_enabled = true
    serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

    expect(serialized[:title]).to eq("This is a test topic title")
    expect(serialized[:bumped]).to eq(true)
    expect(serialized[:featured_link]).to eq(nil)
    expect(serialized[:featured_link_root_domain]).to eq(nil)

    featured_link = "http://meta.discourse.org"
    topic.featured_link = featured_link
    serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

    expect(serialized[:featured_link]).to eq(featured_link)
    expect(serialized[:featured_link_root_domain]).to eq("discourse.org")
  end

  describe "when topic featured link is disable" do
    before { SiteSetting.topic_featured_link_enabled = false }

    it "should not include the topic's featured link" do
      topic.featured_link = "http://meta.discourse.org"
      serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

      expect(serialized[:featured_link]).to eq(nil)
      expect(serialized[:featured_link_root_domain]).to eq(nil)
    end
  end

  describe "hidden tags" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }
    let(:hidden_tag) { Fabricate(:tag, name: "hidden", description: "a" * 1000) }
    let(:staff_tag_group) do
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    end

    before do
      SiteSetting.tagging_enabled = true
      staff_tag_group
      topic.tags << hidden_tag
    end

    it "returns hidden tag to staff" do
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(admin), root: false).as_json

      expect(json[:tags]).to eq([hidden_tag.name])
    end

    it "trucates description" do
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(admin), root: false).as_json
      expect(json[:tags_descriptions]).to eq({ "hidden" => "a" * 77 + "..." })
    end

    it "does not return hidden tag to non-staff" do
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json

      expect(json[:tags]).to eq([])
    end

    it "accepts an option to remove hidden tags" do
      json =
        TopicListItemSerializer.new(
          topic,
          scope: Guardian.new(user),
          hidden_tag_names: [hidden_tag.name],
          root: false,
        ).as_json

      expect(json[:tags]).to eq([])
    end

    it "return posters" do
      json =
        TopicListItemSerializer.new(
          topic,
          scope: Guardian.new(user),
          hidden_tag_names: [hidden_tag.name],
          root: false,
        ).as_json

      expect(json[:posters].length).to eq(1)
    end
  end

  describe "correctly serializes op_likes data" do
    let(:user) { Fabricate(:user) }
    let(:moderator) { Fabricate(:moderator) }
    let(:first_post) { Fabricate(:post, topic: topic, user: user) }
    let(:plugin) { Plugin::Instance.new }

    before { topic.update!(first_post: first_post) }

    it "serializes op_can_like when theme modifies the serialize_topic_op_likes_data to true" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(true)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json[:op_can_like]).to eq(true)
    end

    it "does not include op_can_like when theme modifier disallows" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(false)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json.key?(:op_can_like)).to eq(false)
    end

    it "serializes op_can_like when plugin modifies the serialize_topic_op_likes_data to true" do
      modifier = :serialize_topic_op_likes_data
      proc = Proc.new { true }
      DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json.key?(:op_can_like)).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
    end

    it "serializes op_liked when theme modifies the serialize_topic_op_likes_data to true" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(true)
      PostAction.create!(
        user: user,
        post: first_post,
        post_action_type_id: PostActionType.types[:like],
      )
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json

      expect(json[:op_liked]).to eq(true)
    end

    it "does not include op_liked when theme modifier disallows" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(false)
      PostAction.create!(
        user: user,
        post: first_post,
        post_action_type_id: PostActionType.types[:like],
      )
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json

      expect(json.key?(:op_liked)).to eq(false)
    end

    it "serializes op_liked when plugin modifies the serialize_topic_op_likes_data to true" do
      modifier = :serialize_topic_op_likes_data
      proc = Proc.new { true }
      DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)
      PostAction.create!(
        user: user,
        post: first_post,
        post_action_type_id: PostActionType.types[:like],
      )
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(user), root: false).as_json

      expect(json[:op_liked]).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
    end

    it "serializes first_post_id when theme modifies the serialize_topic_op_likes_data to true" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(true)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json[:first_post_id]).to eq(first_post.id)
    end

    it "does not include first_post_id when theme modifier disallows" do
      allow_any_instance_of(ThemeModifierHelper).to receive(
        :serialize_topic_op_likes_data,
      ).and_return(false)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json.key?(:first_post_id)).to eq(false)
    end

    it "serializes first_post_id when plugin modifies the serialize_topic_op_likes_data to true" do
      modifier = :serialize_topic_op_likes_data
      proc = Proc.new { true }
      DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)
      json = TopicListItemSerializer.new(topic, scope: Guardian.new(moderator), root: false).as_json

      expect(json[:first_post_id]).to eq(first_post.id)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
    end
  end

  describe "#is_hot" do
    describe "including the attr based on theme modifier or plugin registry" do
      fab!(:hot_topic) { Fabricate(:topic) }

      # Caching this directly to workaround the limit heuristic.
      before { Discourse.cache.write(TopicHotScore::CACHE_KEY, Set.new([hot_topic.id])) }
      after { Discourse.cache.delete(TopicHotScore::CACHE_KEY) }

      context "without opt-in" do
        before do
          allow_any_instance_of(ThemeModifierHelper).to receive(:serialize_topic_is_hot).and_return(
            false,
          )
        end

        it "doesn't includes the attr" do
          serialized =
            TopicListItemSerializer.new(hot_topic, scope: Guardian.new, root: false).as_json

          expect(serialized.key?(:is_hot)).to eq(false)
        end
      end

      context "when theme modifier opts-in" do
        before do
          allow_any_instance_of(ThemeModifierHelper).to receive(:serialize_topic_is_hot).and_return(
            true,
          )
        end

        it "returns true if topic is hot" do
          serialized =
            TopicListItemSerializer.new(hot_topic, scope: Guardian.new, root: false).as_json

          expect(serialized[:is_hot]).to eq(true)
        end

        it "returns false if topic is not hot" do
          serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

          expect(serialized[:is_hot]).to eq(false)
        end
      end

      context "when plugin registry opts-in" do
        let(:modifier) { :serialize_topic_is_hot }
        let(:proc) { Proc.new { true } }
        let(:plugin) { Plugin::Instance.new }

        before { DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc) }
        after { DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc) }

        it "returns true if topic is hot" do
          serialized =
            TopicListItemSerializer.new(hot_topic, scope: Guardian.new, root: false).as_json

          expect(serialized[:is_hot]).to eq(true)
        end

        it "returns false if topic is not hot" do
          serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

          expect(serialized[:is_hot]).to eq(false)
        end
      end
    end
  end
end
