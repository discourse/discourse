# frozen_string_literal: true

require 'rails_helper'

describe DestroyTask do

  describe 'destroy topics' do
    fab!(:c) { Fabricate(:category_with_definition) }
    fab!(:t) { Fabricate(:topic, category: c) }
    let!(:p) { Fabricate(:post, topic: t) }
    fab!(:c2) { Fabricate(:category_with_definition) }
    fab!(:t2) { Fabricate(:topic, category: c2) }
    let!(:p2) { Fabricate(:post, topic: t2) }
    fab!(:sc) { Fabricate(:category_with_definition, parent_category: c2) }
    fab!(:t3) { Fabricate(:topic, category: sc) }
    let!(:p3) { Fabricate(:post, topic: t3) }

    it 'destroys all topics in a category' do
      destroy_task = DestroyTask.new(StringIO.new)
      expect { destroy_task.destroy_topics(c.slug) }
        .to change { Topic.where(category_id: c.id).count }.by (-1)
    end

    it 'destroys all topics in a sub category' do
      destroy_task = DestroyTask.new(StringIO.new)
      expect { destroy_task.destroy_topics(sc.slug, c2.slug) }
        .to change { Topic.where(category_id: sc.id).count }.by(-1)
    end

    it "doesn't destroy system topics" do
      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_topics(c2.slug)
      expect(Topic.where(category_id: c2.id).count).to eq 1
    end

    it 'destroys topics in all categories' do
      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_topics_all_categories
      expect(Post.where(topic_id: [t.id, t2.id, t3.id]).count).to eq 0
    end
  end

  describe 'destroy categories' do
    fab!(:c) { Fabricate(:category_with_definition) }
    fab!(:t) { Fabricate(:topic, category: c) }
    let!(:p) { Fabricate(:post, topic: t) }
    fab!(:c2) { Fabricate(:category_with_definition) }
    fab!(:t2) { Fabricate(:topic, category: c) }
    let!(:p2) { Fabricate(:post, topic: t2) }
    fab!(:sc) { Fabricate(:category_with_definition, parent_category: c2) }
    fab!(:t3) { Fabricate(:topic, category: sc) }
    let!(:p3) { Fabricate(:post, topic: t3) }

    it 'destroys specified category' do
      destroy_task = DestroyTask.new(StringIO.new)

      expect { destroy_task.destroy_category(c.id) }
        .to change { Category.where(id: c.id).count }.by (-1)
    end

    it 'destroys sub-categories when destroying parent category' do
      destroy_task = DestroyTask.new(StringIO.new)

      expect { destroy_task.destroy_category(c2.id) }
        .to change { Category.where(id: sc.id).count }.by (-1)
    end
  end

  describe 'private messages' do
    let!(:pm) { Fabricate(:private_message_post) }
    let!(:pm2) { Fabricate(:private_message_post) }

    it 'destroys all private messages' do
      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_private_messages
      expect(Topic.where(archetype: "private_message").count).to eq 0
    end
  end

  describe 'groups' do
    let!(:g) { Fabricate(:group) }
    let!(:g2) { Fabricate(:group) }

    it 'destroys all groups' do
      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_groups
      expect(Group.where(automatic: false).count).to eq 0
    end

    it "doesn't destroy default groups" do
      destroy_task = DestroyTask.new(StringIO.new)
      before_count = Group.count
      destroy_task.destroy_groups
      expect(Group.count).to eq before_count - 2
    end
  end

  describe 'users' do
    it 'destroys all non-admin users' do
      before_count = User.count

      Fabricate(:user)
      Fabricate(:user)
      Fabricate(:admin)

      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_users
      expect(User.where(admin: false).count).to eq 0
      # admin does not get detroyed
      expect(User.count).to eq before_count + 1
    end
  end

  describe 'stats' do
    it 'destroys all site stats' do
      destroy_task = DestroyTask.new(StringIO.new)
      destroy_task.destroy_stats
    end
  end
end
