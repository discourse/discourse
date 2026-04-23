# frozen_string_literal: true

RSpec.describe PostRevisionSerializer do
  fab!(:post) { Fabricate(:post, version: 2) }

  context "with secured categories" do
    fab!(:group)
    fab!(:private_category) { Fabricate(:private_category, group: group) }
    fab!(:post_revision) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "category_id" => [private_category.id, post.topic.category_id],
        },
      )
    end

    it "returns category changes to staff" do
      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:admin)),
          root: false,
        ).as_json

      expect(json[:category_id_changes][:previous]).to eq(private_category.id)
      expect(json[:category_id_changes][:current]).to eq(post.topic.category_id)
    end

    it "does not return all category changes to non-staff" do
      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:category_id_changes][:previous]).to eq(nil)
      expect(json[:category_id_changes][:current]).to eq(post.topic.category_id)
    end
  end

  it "handles tags not being an array" do
    pr = Fabricate(:post_revision, post: post, modifications: { "tags" => ["[]", ""] })

    json =
      PostRevisionSerializer.new(pr, scope: Guardian.new(Fabricate(:user)), root: false).as_json

    expect(json[:tags_changes][:previous]).to eq("[]")
    expect(json[:tags_changes][:current]).to eq([])
  end

  context "with hidden tags" do
    fab!(:public_tag) { Fabricate(:tag, name: "public") }
    fab!(:public_tag2) { Fabricate(:tag, name: "visible") }
    fab!(:hidden_tag) { Fabricate(:tag, name: "hidden") }
    fab!(:hidden_tag2) { Fabricate(:tag, name: "secret") }

    fab!(:staff_tag_group) do
      Fabricate(
        :tag_group,
        permissions: {
          "staff" => 1,
        },
        tag_names: [hidden_tag.name, hidden_tag2.name],
      )
    end

    let(:post_revision) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "tags" => [%w[public hidden], %w[visible hidden]],
        },
      )
    end

    let(:post_revision2) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "tags" => [%w[visible hidden secret], %w[visible hidden]],
        },
      )
    end

    before do
      SiteSetting.tagging_enabled = true
      post.topic.tags = [public_tag2, hidden_tag]
    end

    it "returns all tag changes to staff" do
      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:admin)),
          root: false,
        ).as_json

      expect(json[:tags_changes][:previous]).to contain_exactly(public_tag.name, hidden_tag.name)
      expect(json[:tags_changes][:current]).to contain_exactly(public_tag2.name, hidden_tag.name)
    end

    it "does not return hidden tags to non-staff" do
      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:tags_changes][:previous]).to contain_exactly(public_tag.name)
      expect(json[:tags_changes][:current]).to contain_exactly(public_tag2.name)
    end

    it "does not show tag modifications if changes are not visible to the user" do
      json =
        PostRevisionSerializer.new(
          post_revision2,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:tags_changes]).to_not be_present
    end
  end

  context "when some tracked topic fields are associations" do
    let(:serializer) { described_class.new(post_revision, scope: guardian, root: false) }
    let(:post_revision) { Fabricate(:post_revision, post:) }
    let(:guardian) { Discourse.system_user.guardian }

    before do
      allow(PostRevisor).to receive(:tracked_topic_fields).and_wrap_original do |original_method|
        original_method.call.merge(allowed_users: -> {}, allowed_groups: -> {})
      end
    end

    it "skips them" do
      expect { serializer.as_json }.not_to raise_error
    end
  end

  describe "post locale edits" do
    it "returns the locale changes when set to nothing" do
      post_revision =
        Fabricate(:post_revision, post: post, modifications: { "locale" => ["ja", ""] })

      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:locale_changes][:previous]).to eq("ja")
      expect(json[:locale_changes][:current]).to eq(nil)
    end

    it "returns the locale changes when set from nothing to something" do
      post.update!(locale: "ja")
      post_revision =
        Fabricate(:post_revision, post: post, modifications: { "locale" => ["", "ja"] })

      json =
        PostRevisionSerializer.new(
          post_revision,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:locale_changes][:previous]).to eq(nil)
      expect(json[:locale_changes][:current]).to eq("ja")
    end
  end

  describe "reply_to_post_number edits" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:other_parent) { Fabricate(:post, topic: topic, post_number: 2) }
    fab!(:subject_post) do
      Fabricate(
        :post,
        topic: topic,
        post_number: 3,
        version: 2,
        reply_to_post_number: other_parent.post_number,
      )
    end

    def serialize(revision)
      PostRevisionSerializer.new(
        revision,
        scope: Guardian.new(Fabricate(:user)),
        root: false,
      ).as_json
    end

    it "exposes the change with user info enrichment when the target still exists" do
      revision =
        Fabricate(
          :post_revision,
          post: subject_post,
          modifications: {
            "reply_to_post_number" => [op.post_number, other_parent.post_number],
          },
        )

      json = serialize(revision)

      expect(json[:reply_to_post_number_changes][:previous][:post_number]).to eq(op.post_number)
      expect(json[:reply_to_post_number_changes][:previous][:username]).to eq(
        op.user.username_lower,
      )
      expect(json[:reply_to_post_number_changes][:current][:post_number]).to eq(
        other_parent.post_number,
      )
      expect(json[:reply_to_post_number_changes][:current][:username]).to eq(
        other_parent.user.username_lower,
      )
    end

    it "returns nil on the side that has no reply target" do
      revision =
        Fabricate(
          :post_revision,
          post: subject_post,
          modifications: {
            "reply_to_post_number" => [nil, other_parent.post_number],
          },
        )

      json = serialize(revision)

      expect(json[:reply_to_post_number_changes][:previous]).to be_nil
      expect(json[:reply_to_post_number_changes][:current][:post_number]).to eq(
        other_parent.post_number,
      )
    end

    it "omits the field when reply_to_post_number didn't change" do
      revision =
        Fabricate(:post_revision, post: subject_post, modifications: { "raw" => %w[old new] })

      json = serialize(revision)

      expect(json).not_to have_key(:reply_to_post_number_changes)
    end

    it "does not leak author info for a target the viewer cannot see" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff]
      whisper =
        Fabricate(
          :post,
          topic: topic,
          post_number: 4,
          post_type: Post.types[:whisper],
          user: Fabricate(:user),
        )
      subject_post.update!(reply_to_post_number: whisper.post_number)

      revision =
        Fabricate(
          :post_revision,
          post: subject_post,
          modifications: {
            "reply_to_post_number" => [other_parent.post_number, whisper.post_number],
          },
        )

      json =
        PostRevisionSerializer.new(
          revision,
          scope: Guardian.new(Fabricate(:user)),
          root: false,
        ).as_json

      expect(json[:reply_to_post_number_changes][:current][:post_number]).to eq(whisper.post_number)
      expect(json[:reply_to_post_number_changes][:current]).not_to have_key(:username)
      expect(json[:reply_to_post_number_changes][:current]).not_to have_key(:avatar_template)
    end
  end
end
