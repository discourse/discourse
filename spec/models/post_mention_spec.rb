# frozen_string_literal: true

RSpec.describe PostMention do
  fab!(:post)

  fab!(:user)
  fab!(:category)

  describe "#ensure_exist!" do
    it "creates records from objects" do
      PostMention.ensure_exist!(post_id: post.id, mentions: [user, category])

      expect(post.post_mentions.size).to eq(2)
      expect(post.post_mentions.map(&:mention)).to contain_exactly(user, category)
    end

    it "creates records from IDs" do
      PostMention.ensure_exist!(
        post_id: post.id,
        ids_by_type: {
          user.class.name => [user.id],
          category.class.name => [category.id],
        },
      )

      expect(post.post_mentions.size).to eq(2)
      expect(post.post_mentions.map(&:mention)).to contain_exactly(user, category)
    end

    it "does not create duplicate records" do
      PostMention.create!(post: post, mention: user)
      PostMention.create!(post: post, mention: category)

      PostMention.ensure_exist!(post_id: post.id, mentions: [user, category, user])

      expect(post.post_mentions.size).to eq(2)
      expect(post.post_mentions.map(&:mention)).to contain_exactly(user, category)
    end

    it "deletes records" do
      PostMention.create!(post: post, mention: user)

      PostMention.ensure_exist!(post_id: post.id)

      expect(post.post_mentions.size).to eq(0)
    end

    it "deletes and creates new records" do
      PostMention.create!(post: post, mention: user)

      PostMention.ensure_exist!(post_id: post.id, mentions: [category])

      expect(post.post_mentions.size).to eq(1)
      expect(post.post_mentions.map(&:mention)).to contain_exactly(category)
    end
  end
end
