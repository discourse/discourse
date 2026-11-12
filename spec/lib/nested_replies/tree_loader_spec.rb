# frozen_string_literal: true

RSpec.describe NestedReplies::TreeLoader do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  def create_root(reply_to_post_number: nil, **attributes)
    Fabricate(
      :post,
      topic: topic,
      user: user,
      reply_to_post_number: reply_to_post_number,
      **attributes,
    )
  end

  def create_child(parent, **attributes)
    Fabricate(
      :post,
      topic: topic,
      user: user,
      reply_to_post_number: parent.post_number,
      **attributes,
    )
  end

  def delete_post(post)
    post.update_columns(deleted_at: Time.current)
  end

  describe "#root_posts_scope" do
    it "filters only deleted direct leaves for anonymous and ordinary users" do
      deleted_null_leaf = create_root
      deleted_op_leaf = create_root(reply_to_post_number: 1)
      deleted_root_with_live_child = create_root
      deleted_root_with_deleted_child = create_root(reply_to_post_number: 1)
      live_root_with_deleted_leaf = create_root
      live_root_with_deleted_parent = create_root(reply_to_post_number: 1)

      create_child(deleted_root_with_live_child)
      deleted_child = create_child(deleted_root_with_deleted_child)
      live_deleted_leaf = create_child(live_root_with_deleted_leaf)
      deleted_parent = create_child(live_root_with_deleted_parent)
      deleted_grandchild = create_child(deleted_parent)

      [
        deleted_null_leaf,
        deleted_op_leaf,
        deleted_root_with_live_child,
        deleted_root_with_deleted_child,
        deleted_child,
        live_deleted_leaf,
        deleted_parent,
        deleted_grandchild,
      ].each { |post| delete_post(post) }

      stat =
        NestedViewPostStat.create!(
          post: deleted_root_with_live_child,
          direct_reply_count: 0,
          total_descendant_count: 0,
        )
      expect(stat.reload).to have_attributes(direct_reply_count: 0, total_descendant_count: 0)

      expected_ids = [
        deleted_root_with_live_child.id,
        deleted_root_with_deleted_child.id,
        live_root_with_deleted_leaf.id,
        live_root_with_deleted_parent.id,
      ]

      [Guardian.new, user.guardian].each do |guardian|
        loader = described_class.new(topic: topic, guardian: guardian)
        expect(loader.root_posts_scope("old").pluck(:id)).to eq(expected_ids)
      end
    end

    it "keeps staff root visibility unchanged" do
      deleted_leaf = create_root
      deleted_root_with_child = create_root(reply_to_post_number: 1)
      create_child(deleted_root_with_child)
      delete_post(deleted_leaf)
      delete_post(deleted_root_with_child)

      loader = described_class.new(topic: topic, guardian: Fabricate(:admin).guardian)

      expect(loader.root_posts_scope("old").pluck(:id)).to eq(
        [deleted_leaf.id, deleted_root_with_child.id],
      )
    end

    it "uses requester-aware post type visibility for direct children" do
      whisper_group = Fabricate(:group)
      whisperer = Fabricate(:user, refresh_auto_groups: true)
      whisper_group.add(whisperer)
      SiteSetting.whispers_allowed_groups = whisper_group.id.to_s

      regular_child_root = create_root
      moderator_child_root = create_root
      small_action_child_root = create_root
      whisper_child_root = create_root
      action_whisper_child_root = create_root

      create_child(regular_child_root)
      create_child(moderator_child_root, post_type: Post.types[:moderator_action])
      create_child(small_action_child_root, post_type: Post.types[:small_action])
      create_child(whisper_child_root, post_type: Post.types[:whisper])
      create_child(
        action_whisper_child_root,
        post_type: Post.types[:whisper],
        action_code: "assigned",
      )

      [
        regular_child_root,
        moderator_child_root,
        small_action_child_root,
        whisper_child_root,
        action_whisper_child_root,
      ].each { |root| delete_post(root) }

      ordinary_loader = described_class.new(topic: topic, guardian: user.guardian)
      whisperer_loader = described_class.new(topic: topic, guardian: whisperer.guardian)

      expect(ordinary_loader.root_posts_scope("old").pluck(:id)).to eq(
        [regular_child_root.id, moderator_child_root.id],
      )
      expect(whisperer_loader.root_posts_scope("old").pluck(:id)).to eq(
        [regular_child_root.id, moderator_child_root.id, whisper_child_root.id],
      )
    end

    it "filters before page boundaries for every root sort" do
      eligible_roots = 5.times.map { |index| create_root(like_count: index + 1) }
      hidden_roots = 4.times.map { |index| create_root(like_count: index + 10) }
      hidden_roots.each { |root| delete_post(root) }
      loader = described_class.new(topic: topic, guardian: user.guardian)

      %w[old new top hot].each do |sort|
        paged_ids =
          3.times.flat_map do |page|
            loader.root_posts_scope(sort).offset(page * 2).limit(2).pluck(:id)
          end

        expect(paged_ids).to contain_exactly(*eligible_roots.map(&:id))
      end
    end
  end

  describe "#promote_pinned_roots" do
    it "uses nonstaff root eligibility for pins outside the input page" do
      deleted_leaf = create_root
      deleted_root_with_child = create_root(reply_to_post_number: 1)
      child = create_child(deleted_root_with_child)
      delete_post(deleted_leaf)
      delete_post(deleted_root_with_child)
      pinned_ids = [deleted_leaf.id, deleted_root_with_child.id]

      ordinary_loader = described_class.new(topic: topic, guardian: user.guardian)
      staff_loader = described_class.new(topic: topic, guardian: Fabricate(:admin).guardian)

      expect(ordinary_loader.promote_pinned_roots([], pinned_ids).map(&:id)).to eq(
        [deleted_root_with_child.id],
      )
      expect(ordinary_loader.promote_pinned_roots([], pinned_ids).first).to have_attributes(
        deleted_at: be_present,
        post_number: deleted_root_with_child.post_number,
      )
      expect(child.reply_to_post_number).to eq(deleted_root_with_child.post_number)
      expect(staff_loader.promote_pinned_roots([], pinned_ids)).to eq([])
    end

    it "leaves a staff-visible deleted pin in its original input-page position" do
      first_root = create_root
      deleted_pinned_root = create_root
      last_root = create_root
      delete_post(deleted_pinned_root)
      loader = described_class.new(topic: topic, guardian: Fabricate(:admin).guardian)

      promoted =
        loader.promote_pinned_roots(
          [first_root, deleted_pinned_root, last_root],
          [deleted_pinned_root.id],
        )

      expect(promoted.map(&:id)).to eq([first_root.id, deleted_pinned_root.id, last_root.id])
    end
  end
end
