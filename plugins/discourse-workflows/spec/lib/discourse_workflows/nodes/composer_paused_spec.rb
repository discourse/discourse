# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ComposerPaused::V1 do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:subcategory) { Fabricate(:category, parent_category: category) }
  fab!(:topic) { Fabricate(:topic, category:) }

  def snapshot(**attrs)
    DiscourseWorkflows::ComposerSnapshot.new(
      **{ user:, action: "create_topic", draft_key: "new_topic", raw: "Some text" }.merge(attrs),
    )
  end

  describe "#output" do
    it "matches the declared schema for a new topic" do
      output =
        described_class.new(
          snapshot(title: "Lunch review", category_id: category.id),
          ["food stand"],
        ).output

      expect(output).to match_node_output_schema(described_class)
      expect(output[:user][:id]).to eq(user.id)
      expect(output[:actor][:id]).to eq(user.id)
      expect(output[:topic]).to be_nil
      expect(output[:composer]).to eq(
        action: "create_topic",
        draft_key: "new_topic",
        session_id: nil,
        title: "Lunch review",
        raw: "Some text",
        category_id: category.id,
        topic_id: nil,
        reply_to_post_number: nil,
        matched_phrases: ["food stand"],
      )
    end

    it "matches the declared schema for a reply" do
      output =
        described_class.new(
          snapshot(
            action: "reply",
            draft_key: "topic_#{topic.id}",
            session_id: "session-1",
            topic:,
            reply_to_post_number: 2,
          ),
        ).output

      expect(output).to match_node_output_schema(described_class)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:composer]).to include(
        action: "reply",
        session_id: "session-1",
        topic_id: topic.id,
        category_id: category.id,
        reply_to_post_number: 2,
        matched_phrases: [],
      )
    end
  end

  describe ".matched_phrases" do
    let(:phrases) do
      described_class.phrases("phrases" => ["Magic words", "bad food*", " food stand "])
    end

    it "matches whole phrases ignoring case, with watched word wildcards" do
      expect(
        described_class.matched_phrases(phrases, "Some MAGIC WORDS and bad foods"),
      ).to contain_exactly("Magic words", "bad food*")
      expect(described_class.matched_phrases(phrases, "food stands")).to be_empty
      expect(described_class.matched_phrases(phrases, "food stand")).to eq(["food stand"])
    end
  end

  describe ".validate_configuration" do
    def errors_for(phrases)
      errors = ActiveModel::Errors.new(DiscourseWorkflows::Workflow.new)
      described_class.validate_configuration({ "phrases" => phrases }, errors)
      errors.full_messages
    end

    it "accepts valid phrases" do
      expect(errors_for(["Magic words", "bad food*"])).to be_empty
    end

    it "rejects phrases that match nearly any text" do
      expect(errors_for(["*", "* *"]).size).to eq(2)
    end

    it "rejects invalid and match-anything regular expressions" do
      SiteSetting.watched_words_regular_expressions = true

      expect(errors_for(["Magic words|", ".", "(unclosed"]).size).to eq(3)
      expect(errors_for(['\d{4}'])).to be_empty
    end

    it "rejects regular expressions that could take too long to match" do
      SiteSetting.watched_words_regular_expressions = true

      expect(errors_for(['(a+)+\1'])).to eq(
        [I18n.t("discourse_workflows.errors.composer_paused.invalid_phrase", phrase: '(a+)+\1')],
      )
      expect(described_class.patterns("phrases" => ['(a+)+\1'])).to be_empty
    end

    it "rejects too many or too long phrases" do
      expect(errors_for(Array.new(described_class::MAX_PHRASES + 1) { |i| "phrase #{i}" })).to eq(
        [
          I18n.t(
            "discourse_workflows.errors.composer_paused.too_many_phrases",
            max: described_class::MAX_PHRASES,
          ),
        ],
      )
      expect(errors_for(["a" * (described_class::MAX_PHRASE_LENGTH + 1)]).size).to eq(1)
    end
  end

  describe ".matches_snapshot?" do
    it "only fires for the configured composer actions" do
      parameters = { "composer_actions" => ["reply"] }

      expect(described_class.matches_snapshot?(parameters, snapshot)).to eq(false)
      expect(
        described_class.matches_snapshot?(
          parameters,
          snapshot(action: "reply", draft_key: "topic_#{topic.id}", topic:),
        ),
      ).to eq(true)
    end

    it "never fires for replies to personal messages" do
      pm = Fabricate(:private_message_topic, user:)

      expect(
        described_class.matches_snapshot?(
          {},
          snapshot(action: "reply", draft_key: "topic_#{pm.id}", topic: pm),
        ),
      ).to eq(false)
    end

    it "filters by category, including subcategories unless disabled" do
      parameters = { "category_ids" => [category.id] }

      expect(described_class.matches_snapshot?(parameters, snapshot)).to eq(false)
      expect(
        described_class.matches_snapshot?(parameters, snapshot(category_id: subcategory.id)),
      ).to eq(true)
      expect(
        described_class.matches_snapshot?(
          parameters.merge("include_subcategories" => false),
          snapshot(category_id: subcategory.id),
        ),
      ).to eq(false)
    end

    it "filters by group, firing for everyone without groups" do
      group = Fabricate(:group)

      expect(described_class.matches_snapshot?({}, snapshot)).to eq(true)
      expect(described_class.matches_snapshot?({ "group_ids" => [group.id] }, snapshot)).to eq(
        false,
      )

      group.add(user)
      expect(
        described_class.matches_snapshot?(
          { "group_ids" => [group.id] },
          snapshot(user: User.find(user.id)),
        ),
      ).to eq(true)
    end

    it "requires the user to be able to post there" do
      staff_category = Fabricate(:private_category, group: Group[:staff])

      expect(described_class.matches_snapshot?({}, snapshot(category_id: staff_category.id))).to eq(
        false,
      )
    end
  end
end
