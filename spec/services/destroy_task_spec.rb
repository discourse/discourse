require 'rails_helper'

describe DestroyTask do

  describe 'destroy topics' do
    let!(:c) { Fabricate(:category) }
    let!(:t) { Fabricate(:topic, category: c) }
    let!(:p) { Fabricate(:post, topic: t) }
    let!(:c2) { Fabricate(:category) }
    let!(:t2) { Fabricate(:topic, category: c2) }
    let!(:p2) { Fabricate(:post, topic: t2) }
    let!(:sc) { Fabricate(:category, parent_category: c) }
    let!(:t3) { Fabricate(:topic, category: sc) }
    let!(:p3) { Fabricate(:post, topic: t3) }

    it 'destroys all topics in a category' do
      expect { DestroyTask.destroy_topics(c.slug) }
        .to change { Topic.where(category_id: c.id).count }.by (-1)
    end

    it 'destroys all topics in a sub category' do
      expect { DestroyTask.destroy_topics(sc.slug, c.slug) }
        .to change { Topic.where(category_id: sc.id).count }.by(-1)
    end

    it "doesn't destroy system topics" do
      DestroyTask.destroy_topics(c2.slug)
      expect(Topic.where(category_id: c2.id).count).to eq 1
    end

    it 'destroys topics in all categories' do
      DestroyTask.destroy_topics_all_categories
      expect(Post.where(topic_id: [t.id, t2.id, t3.id]).count).to eq 0
    end
  end

  describe 'private messages' do
    let!(:pm) { Fabricate(:private_message_post) }
    let!(:pm2) { Fabricate(:private_message_post) }

    it 'destroys all private messages' do
      DestroyTask.destroy_private_messages
      expect(Topic.where(archetype: "private_message").count).to eq 0
    end
  end

  describe 'groups' do
    let!(:g) { Fabricate(:group) }
    let!(:g2) { Fabricate(:group) }

    it 'destroys all groups' do
      DestroyTask.destroy_groups
      expect(Group.where(automatic: false).count).to eq 0
    end

    it "doesn't destroy default groups" do
      before_count = Group.count
      DestroyTask.destroy_groups
      expect(Group.count).to eq before_count - 2
    end
  end

  describe 'users' do
    it 'destroys all non-admin users' do
      before_count = User.count

      Fabricate(:user)
      Fabricate(:user)
      Fabricate(:admin)

      DestroyTask.destroy_users
      expect(User.where(admin: false).count).to eq 0
      # admin does not get detroyed
      expect(User.count).to eq before_count + 1
    end
  end

  describe 'stats' do
    it 'destroys all site stats' do
      DestroyTask.destroy_stats
    end
  end
end
