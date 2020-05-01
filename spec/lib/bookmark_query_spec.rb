# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BookmarkQuery do
  fab!(:user) { Fabricate(:user) }
  let(:params) { {} }

  def bookmark_query(user: nil, params: nil)
    BookmarkQuery.new(user: user || self.user, params: params || self.params)
  end

  describe "#list_all" do
    fab!(:bookmark1) { Fabricate(:bookmark, user: user) }
    fab!(:bookmark2) { Fabricate(:bookmark, user: user) }

    it "returns all the bookmarks for a user" do
      expect(bookmark_query.list_all.count).to eq(2)
    end

    it "does not return deleted posts" do
      bookmark1.post.trash!
      expect(bookmark_query.list_all.count).to eq(1)
    end

    it "does not return deleted topics" do
      bookmark1.topic.trash!
      expect(bookmark_query.list_all.count).to eq(1)
    end

    it "runs the on_preload block provided passing in bookmarks" do
      preloaded_bookmarks = []
      BookmarkQuery.on_preload do |bookmarks, bq|
        (preloaded_bookmarks << bookmarks).flatten
      end
      bookmark_query.list_all
      expect(preloaded_bookmarks.any?).to eq(true)
    end

    context "for a whispered post" do
      before do
        bookmark1.post.update(post_type: Post.types[:whisper])
      end
      context "when the user is moderator" do
        it "does return the whispered post" do
          user.update!(moderator: true)
          expect(bookmark_query.list_all.count).to eq(2)
        end
      end
      context "when the user is admin" do
        it "does return the whispered post" do
          user.update!(admin: true)
          expect(bookmark_query.list_all.count).to eq(2)
        end
      end
      context "when the user is not staff" do
        it "does not return the whispered post" do
          expect(bookmark_query.list_all.count).to eq(1)
        end
      end
    end

    context "for a private message topic bookmark" do
      let(:pm_topic) { Fabricate(:private_message_topic) }
      before do
        bookmark1.update(topic: pm_topic, post: Fabricate(:post, topic: pm_topic))
        TopicUser.change(user.id, pm_topic.id, total_msecs_viewed: 1)
      end

      context "when the user is a topic_allowed_user" do
        before do
          TopicAllowedUser.create(topic: pm_topic, user: user)
        end
        it "shows the user the bookmark in the PM" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(2)
        end
      end

      context "when the user is in a topic_allowed_group" do
        before do
          group = Fabricate(:group)
          GroupUser.create(group: group, user: user)
          TopicAllowedGroup.create(topic: pm_topic, group: group)
        end
        it "shows the user the bookmark in the PM" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(2)
        end
      end

      context "when the user is not a topic_allowed_user" do
        it "does not show the user a bookmarked post in a PM where they are not an allowed user" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(1)
        end
      end

      context "when the user is not in a topic_allowed_group" do
        it "does not show the user a bookmarked post in a PM where they are not in an allowed group" do
          expect(bookmark_query.list_all.map(&:id).count).to eq(1)
        end
      end
    end

    context "when the topic category is private" do
      let(:group) { Fabricate(:group) }
      before do
        bookmark1.topic.update(category: Fabricate(:private_category, group: group))
        bookmark1.reload
      end
      it "does not show the user a post/topic in a private category they cannot see" do
        expect(bookmark_query.list_all.map(&:id)).not_to include(bookmark1.id)
      end
      it "does show the user a post/topic in a private category they can see" do
        GroupUser.create(user: user, group: group)
        expect(bookmark_query.list_all.map(&:id)).to include(bookmark1.id)
      end
    end

    context "when the limit param is provided" do
      let(:params) { { limit: 1 } }
      it "is respected" do
        expect(bookmark_query.list_all.count).to eq(1)
      end
    end

    context "when there are topic custom fields to preload" do
      before do
        TopicCustomField.create(
          topic_id: bookmark1.topic.id, name: 'test_field', value: 'test'
        )
        BookmarkQuery.preloaded_custom_fields << "test_field"
      end
      it "preloads them" do
        Topic.expects(:preload_custom_fields)
        expect(
          bookmark_query.list_all.find do |b|
            b.topic_id = bookmark1.topic_id
          end.topic.custom_fields['test_field']
        ).not_to eq(nil)
      end
    end
  end

  describe "#list_all ordering" do
    let!(:bookmark1) { Fabricate(:bookmark, user: user, updated_at: 1.day.ago) }
    let!(:bookmark2) { Fabricate(:bookmark, user: user, updated_at: 2.days.ago) }
    let!(:bookmark3) { Fabricate(:bookmark, user: user, updated_at: 6.days.ago) }
    let!(:bookmark4) { Fabricate(:bookmark, user: user, updated_at: 4.days.ago) }
    let!(:bookmark5) { Fabricate(:bookmark, user: user, updated_at: 3.days.ago) }
    it "orders by updated_at" do
      expect(bookmark_query.list_all.map(&:id)).to eq([
        bookmark1.id,
        bookmark2.id,
        bookmark5.id,
        bookmark4.id,
        bookmark3.id
      ])
    end
  end
end
