# frozen_string_literal: true

RSpec.describe NestedReplies::TreeLoader do
  fab!(:user)
  fab!(:ignored_user, :user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  let(:guardian) { Guardian.new(user) }
  let(:loader) { described_class.new(topic: topic, guardian: guardian) }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:ignored_user, user: user, ignored_user: ignored_user)
  end

  describe "#root_posts_scope" do
    fab!(:visible_root) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
    fab!(:ignored_root) do
      Fabricate(:post, topic: topic, user: ignored_user, reply_to_post_number: 1)
    end

    it "excludes root posts from ignored users" do
      ids = loader.root_posts_scope("top").pluck(:id)
      expect(ids).to include(visible_root.id)
      expect(ids).not_to include(ignored_root.id)
    end

    context "when anonymous (no current user)" do
      let(:guardian) { Guardian.new }

      it "does not filter anything" do
        ids = loader.root_posts_scope("top").pluck(:id)
        expect(ids).to include(visible_root.id, ignored_root.id)
      end
    end

    context "when the ignored user is staff" do
      fab!(:ignored_user) { Fabricate(:user, admin: true) }

      it "keeps staff posts even if ignored" do
        ids = loader.root_posts_scope("top").pluck(:id)
        expect(ids).to include(visible_root.id, ignored_root.id)
      end
    end
  end

  describe "#batch_preload_tree" do
    fab!(:root) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
    fab!(:visible_child) do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
    end
    fab!(:ignored_child) do
      Fabricate(:post, topic: topic, user: ignored_user, reply_to_post_number: root.post_number)
    end

    it "excludes child posts from ignored users" do
      tree = loader.batch_preload_tree([root], "top", max_depth: 2)
      post_ids = tree[:all_posts].map(&:id)
      expect(post_ids).to include(visible_child.id)
      expect(post_ids).not_to include(ignored_child.id)
    end
  end

  describe "#flat_descendants_scope" do
    fab!(:root) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
    fab!(:visible_descendant) do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
    end
    fab!(:ignored_descendant) do
      Fabricate(:post, topic: topic, user: ignored_user, reply_to_post_number: root.post_number)
    end

    it "excludes descendants from ignored users" do
      ids = loader.flat_descendants_scope(root.post_number, sort: "top").pluck(:id)
      expect(ids).to include(visible_descendant.id)
      expect(ids).not_to include(ignored_descendant.id)
    end
  end

  describe "#batch_load_siblings" do
    fab!(:parent_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
    fab!(:ancestor) do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent_post.post_number)
    end
    fab!(:visible_sibling) do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: parent_post.post_number)
    end
    fab!(:ignored_sibling) do
      Fabricate(
        :post,
        topic: topic,
        user: ignored_user,
        reply_to_post_number: parent_post.post_number,
      )
    end

    it "excludes sibling posts from ignored users" do
      siblings_map = loader.batch_load_siblings([ancestor], "top")
      sibling_ids = siblings_map[ancestor.post_number].map(&:id)
      expect(sibling_ids).to include(visible_sibling.id)
      expect(sibling_ids).not_to include(ignored_sibling.id)
    end
  end

  describe "#direct_reply_counts" do
    fab!(:root) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: 1) }
    fab!(:visible_reply) do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
    end
    fab!(:ignored_reply) do
      Fabricate(:post, topic: topic, user: ignored_user, reply_to_post_number: root.post_number)
    end

    it "does not count replies from ignored users" do
      counts = loader.direct_reply_counts([root.post_number])
      expect(counts[root.post_number]).to eq(1)
    end
  end

  describe "#op_post" do
    it "returns the OP even when its author is ignored" do
      ignored_op_topic = Fabricate(:topic, user: ignored_user)
      ignored_op = Fabricate(:post, topic: ignored_op_topic, user: ignored_user, post_number: 1)
      ignored_loader = described_class.new(topic: ignored_op_topic, guardian: guardian)

      expect(ignored_loader.op_post&.id).to eq(ignored_op.id)
    end
  end
end
