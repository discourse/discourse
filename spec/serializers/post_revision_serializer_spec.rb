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
end
