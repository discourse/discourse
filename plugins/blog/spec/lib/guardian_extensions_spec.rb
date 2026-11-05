# frozen_string_literal: true

RSpec.describe Blog::GuardianExtensions do
  fab!(:admin)
  fab!(:moderator)
  fab!(:writers, :group)
  fab!(:editors, :group)
  fab!(:writer) { Fabricate(:user, groups: [writers]) }
  fab!(:editor) { Fabricate(:user, groups: [editors]) }
  fab!(:category)
  fab!(:drafts) do
    Fabricate(:private_category, group: Group[:staff]).tap do |drafts|
      drafts.set_permissions(:staff => :full, writers.name => :full, editors.name => :full)
      drafts.save!
    end
  end

  fab!(:article) { Fabricate(:topic, category: category, user: admin) }
  fab!(:article_post) { Fabricate(:post, topic: article, user: admin) }
  fab!(:publication) do
    Blog::Publication.create!(
      topic: article,
      discussion_topic: article,
      path: "/article",
      published: true,
      published_at: 1.day.ago,
    )
  end

  fab!(:writer_draft) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:writer_draft_post) { Fabricate(:post, topic: writer_draft, user: writer) }
  fab!(:admin_draft) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:admin_draft_post) { Fabricate(:post, topic: admin_draft, user: admin) }

  before do
    enable_blog!(category: category, drafts: drafts)
    SiteSetting.blog_contributor_groups = writers.id.to_s
    SiteSetting.blog_editor_groups = editors.id.to_s
  end

  def share_drafts_with(group)
    drafts.set_permissions(
      :staff => :full,
      writers.name => :full,
      editors.name => :full,
      group.name => :full,
    )
    drafts.save!
  end

  describe "#can_edit_post?" do
    context "with the first post of a published article" do
      it "denies everyone, including admins" do
        expect(admin.guardian.can_edit_post?(article_post)).to eq(false)
        expect(editor.guardian.can_edit_post?(article_post)).to eq(false)
        expect(Guardian.new.can_edit?(article_post)).to eq(false)
      end

      it "falls back to core rules when the blog is disabled" do
        SiteSetting.blog_enabled = false

        expect(admin.guardian.can_edit_post?(article_post)).to eq(true)
      end

      it "falls back to core rules before the article has a published revision" do
        publication.update_columns(published_revision_id: nil)

        expect(admin.guardian.can_edit_post?(article_post)).to eq(true)
      end

      it "leaves replies to core rules" do
        reply = Fabricate(:post, topic: article, user: writer)

        expect(admin.guardian.can_edit_post?(reply)).to eq(true)
      end
    end

    context "with the first post of an editorial draft" do
      it "allows contributors to edit their own draft" do
        expect(writer.guardian.can_edit_post?(writer_draft_post)).to eq(true)
      end

      it "allows editors to edit drafts they do not own" do
        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(true)
      end

      it "denies contributors someone else's draft" do
        expect(writer.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies users whose editor role was removed" do
        SiteSetting.blog_editor_groups = ""

        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies editors who cannot see the drafts category" do
        drafts.set_permissions(:staff => :full, writers.name => :full)
        drafts.save!

        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies suspended and silenced editors" do
        suspended = Fabricate(:user, groups: [editors], suspended_till: 1.day.from_now)
        silenced = Fabricate(:user, groups: [editors], silenced_till: 1.day.from_now)

        expect(suspended.guardian.can_edit_post?(admin_draft_post)).to eq(false)
        expect(silenced.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies anonymous users" do
        expect(Guardian.new.can_edit?(writer_draft_post)).to eq(false)
      end

      it "denies editors when the blog is disabled" do
        SiteSetting.blog_enabled = false

        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies editors a hidden or locked first post" do
        admin_draft_post.update_columns(hidden: true)
        writer_draft_post.update_columns(locked_by_id: admin.id)

        expect(editor.guardian.can_edit_post?(admin_draft_post.reload)).to eq(false)
        expect(editor.guardian.can_edit_post?(writer_draft_post.reload)).to eq(false)
      end

      it "denies editors a deleted first post" do
        admin_draft_post.update_columns(deleted_at: Time.current)

        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "allows staff to edit a locked first post" do
        admin_draft_post.update_columns(locked_by_id: admin.id)

        expect(moderator.guardian.can_edit_post?(admin_draft_post.reload)).to eq(true)
      end

      it "denies editors an archived draft" do
        admin_draft.update_columns(archived: true)

        expect(editor.guardian.can_edit_post?(admin_draft_post.reload)).to eq(false)
      end

      it "denies editors the drafts category description" do
        drafts.update_columns(topic_id: admin_draft.id)

        expect(editor.guardian.can_edit_post?(admin_draft_post)).to eq(false)
      end

      it "denies editors drafts outside the drafts category" do
        other = Fabricate(:post, topic: Fabricate(:topic, category: category, user: admin))

        expect(editor.guardian.can_edit_post?(other)).to eq(false)
      end

      it "leaves editorial replies to core rules" do
        reply = Fabricate(:post, topic: admin_draft, user: admin)

        expect(editor.guardian.can_edit_post?(reply)).to eq(false)
      end

      it "denies editors unlisted and shared drafts" do
        admin_draft.update_columns(visible: false)
        SharedDraft.create!(topic: writer_draft, category: category)

        expect(editor.guardian.can_edit_post?(admin_draft_post.reload)).to eq(false)
        expect(editor.guardian.can_edit_post?(writer_draft_post.reload)).to eq(false)
      end

      it "denies editors other members' topics when the drafts category is public" do
        public_drafts = Fabricate(:category)
        member_topic = Fabricate(:topic, category: public_drafts)
        member_post = Fabricate(:post, topic: member_topic, user: member_topic.user)
        SiteSetting.blog_drafts_category = public_drafts.id

        expect(editor.guardian.can_edit_post?(member_post)).to eq(false)
        expect(admin.guardian.can_edit_post?(member_post)).to eq(true)
      end

      it "denies contributors their own post past the edit time limit when the drafts category is public" do
        public_drafts = Fabricate(:category)
        own_topic = Fabricate(:topic, category: public_drafts, user: writer)
        own_post = Fabricate(:post, topic: own_topic, user: writer, created_at: 1.hour.ago)
        SiteSetting.blog_drafts_category = public_drafts.id
        SiteSetting.post_edit_time_limit = 1
        SiteSetting.tl2_post_edit_time_limit = 1

        expect(writer.guardian.can_edit_post?(own_post)).to eq(false)
      end

      it "denies editors other members' topics when the drafts category is shared with another group" do
        members = Fabricate(:group)
        member = Fabricate(:user, groups: [members])
        share_drafts_with(members)
        member_topic = Fabricate(:topic, category: drafts, user: member)
        member_post = Fabricate(:post, topic: member_topic, user: member)

        expect(editor.guardian.can_edit_post?(member_post)).to eq(false)
        expect(admin.guardian.can_edit_post?(member_post)).to eq(true)
      end

      it "denies contributors their own post past the edit time limit when the drafts category is shared with another group" do
        share_drafts_with(Fabricate(:group))
        writer_draft_post.update_columns(created_at: 1.hour.ago)
        SiteSetting.post_edit_time_limit = 1
        SiteSetting.tl2_post_edit_time_limit = 1

        expect(writer.guardian.can_edit_post?(writer_draft_post)).to eq(false)
      end
    end
  end

  describe "#can_edit_topic?" do
    context "with a published article's topic" do
      it "denies everyone, including admins" do
        expect(admin.guardian.can_edit_topic?(article)).to eq(false)
        expect(editor.guardian.can_edit_topic?(article)).to eq(false)
        expect(Guardian.new.can_edit?(article)).to eq(false)
      end

      it "falls back to core rules when the blog is disabled" do
        SiteSetting.blog_enabled = false

        expect(admin.guardian.can_edit_topic?(article)).to eq(true)
      end
    end

    context "with an editorial draft" do
      it "allows contributors to edit their own draft" do
        expect(writer.guardian.can_edit_topic?(writer_draft)).to eq(true)
      end

      it "allows editors to edit drafts they do not own" do
        expect(editor.guardian.can_edit_topic?(admin_draft)).to eq(true)
      end

      it "denies contributors someone else's draft" do
        expect(writer.guardian.can_edit_topic?(admin_draft)).to eq(false)
      end

      it "denies anonymous users" do
        expect(Guardian.new.can_edit?(writer_draft)).to eq(false)
      end

      it "denies editors when the blog is disabled" do
        SiteSetting.blog_enabled = false

        expect(editor.guardian.can_edit_topic?(admin_draft)).to eq(false)
      end

      it "denies editors a draft whose first post is locked, but allows staff" do
        admin_draft_post.update_columns(locked_by_id: admin.id)

        expect(editor.guardian.can_edit_topic?(admin_draft.reload)).to eq(false)
        expect(moderator.guardian.can_edit_topic?(admin_draft)).to eq(true)
      end

      it "denies editors an archived draft" do
        admin_draft.update_columns(archived: true)

        expect(editor.guardian.can_edit_topic?(admin_draft.reload)).to eq(false)
      end

      it "denies editors the drafts category description topic" do
        drafts.update_columns(topic_id: admin_draft.id)

        expect(editor.guardian.can_edit_topic?(admin_draft)).to eq(false)
      end

      it "denies editors a draft whose first post is hidden" do
        admin_draft_post.update_columns(hidden: true)

        expect(editor.guardian.can_edit_topic?(admin_draft.reload)).to eq(false)
      end

      it "denies editors unlisted and shared drafts" do
        admin_draft.update_columns(visible: false)
        SharedDraft.create!(topic: writer_draft, category: category)

        expect(editor.guardian.can_edit_topic?(admin_draft.reload)).to eq(false)
        expect(editor.guardian.can_edit_topic?(writer_draft)).to eq(false)
      end

      it "denies editors other members' topics when the drafts category is public" do
        public_drafts = Fabricate(:category)
        member_topic = Fabricate(:topic, category: public_drafts)
        Fabricate(:post, topic: member_topic, user: member_topic.user)
        SiteSetting.blog_drafts_category = public_drafts.id

        expect(editor.guardian.can_edit_topic?(member_topic)).to eq(false)
        expect(moderator.guardian.can_edit_topic?(member_topic)).to eq(true)
      end

      it "denies contributors their own topic in a public drafts category they cannot post in" do
        public_drafts = Fabricate(:category)
        own_topic = Fabricate(:topic, category: public_drafts, user: writer)
        Fabricate(:post, topic: own_topic, user: writer)
        public_drafts.set_permissions(everyone: :readonly)
        public_drafts.save!
        SiteSetting.blog_drafts_category = public_drafts.id

        expect(writer.guardian.can_edit_topic?(own_topic)).to eq(false)
      end

      it "denies editors other members' topics when the drafts category is shared with another group" do
        members = Fabricate(:group)
        member = Fabricate(:user, groups: [members])
        share_drafts_with(members)
        member_topic = Fabricate(:topic, category: drafts, user: member)
        Fabricate(:post, topic: member_topic, user: member)

        expect(editor.guardian.can_edit_topic?(member_topic)).to eq(false)
        expect(moderator.guardian.can_edit_topic?(member_topic)).to eq(true)
      end

      it "denies contributors their own topic past the edit time limit when the drafts category is shared with another group" do
        share_drafts_with(Fabricate(:group))
        writer_draft.update_columns(created_at: 1.hour.ago)
        SiteSetting.post_edit_time_limit = 1
        SiteSetting.tl2_post_edit_time_limit = 1

        expect(writer.guardian.can_edit_topic?(writer_draft)).to eq(false)
      end

      it "checks a new drafts category's sharing when the same guardian is reused" do
        members = Fabricate(:group)
        shared_drafts = Fabricate(:private_category, group: Group[:staff])
        shared_drafts.set_permissions(:staff => :full, editors.name => :full, members.name => :full)
        shared_drafts.save!
        member_topic =
          Fabricate(:topic, category: shared_drafts, user: Fabricate(:user, groups: [members]))
        guardian = editor.guardian

        expect(guardian.can_edit_topic?(admin_draft)).to eq(true)

        SiteSetting.blog_drafts_category = shared_drafts.id

        expect(guardian.can_edit_topic?(member_topic)).to eq(false)
      end
    end
  end

  describe "#is_blog_publisher?" do
    fab!(:publishers, :group)
    fab!(:publisher) { Fabricate(:user, groups: [publishers]) }

    before { SiteSetting.blog_publisher_groups = publishers.id.to_s }

    it "allows admins and members of the publisher groups" do
      expect(admin.guardian.is_blog_publisher?).to eq(true)
      expect(publisher.guardian.is_blog_publisher?).to eq(true)
    end

    it "denies other staff, editors, contributors and anonymous users" do
      expect(moderator.guardian.is_blog_publisher?).to eq(false)
      expect(editor.guardian.is_blog_publisher?).to eq(false)
      expect(writer.guardian.is_blog_publisher?).to eq(false)
      expect(Guardian.new.is_blog_publisher?).to eq(false)
    end

    it "matches staff auto groups by role" do
      SiteSetting.blog_publisher_groups = Group::AUTO_GROUPS[:moderators].to_s

      expect(moderator.guardian.is_blog_publisher?).to eq(true)
    end

    it "denies inactive, suspended and silenced publishers" do
      inactive = Fabricate(:user, groups: [publishers], active: false)
      suspended = Fabricate(:user, groups: [publishers], suspended_till: 1.day.from_now)
      silenced = Fabricate(:user, groups: [publishers], silenced_till: 1.day.from_now)

      expect(inactive.guardian.is_blog_publisher?).to eq(false)
      expect(suspended.guardian.is_blog_publisher?).to eq(false)
      expect(silenced.guardian.is_blog_publisher?).to eq(false)
    end

    it "denies admins when the blog is disabled" do
      SiteSetting.blog_enabled = false

      expect(admin.guardian.is_blog_publisher?).to eq(false)
    end
  end

  describe "#is_blog_editor?" do
    it "allows members of the editor groups and publishers" do
      expect(editor.guardian.is_blog_editor?).to eq(true)
      expect(admin.guardian.is_blog_editor?).to eq(true)
    end

    it "denies contributors and anonymous users" do
      expect(writer.guardian.is_blog_editor?).to eq(false)
      expect(Guardian.new.is_blog_editor?).to eq(false)
    end
  end

  describe "#is_blog_contributor?" do
    it "allows members of the contributor groups, editors and publishers" do
      expect(writer.guardian.is_blog_contributor?).to eq(true)
      expect(editor.guardian.is_blog_contributor?).to eq(true)
      expect(admin.guardian.is_blog_contributor?).to eq(true)
    end

    it "denies other users and anonymous users" do
      expect(Fabricate(:user).guardian.is_blog_contributor?).to eq(false)
      expect(Guardian.new.is_blog_contributor?).to eq(false)
    end
  end

  describe "#can_edit_blog_topic?" do
    it "allows contributors their own articles and editors any article" do
      expect(writer.guardian.can_edit_blog_topic?(writer_draft)).to eq(true)
      expect(editor.guardian.can_edit_blog_topic?(admin_draft)).to eq(true)
      expect(editor.guardian.can_edit_blog_topic?(article)).to eq(true)
    end

    it "denies contributors someone else's article" do
      expect(writer.guardian.can_edit_blog_topic?(admin_draft)).to eq(false)
    end

    it "denies editors who cannot see the topic" do
      drafts.set_permissions(:staff => :full, writers.name => :full)
      drafts.save!

      expect(editor.guardian.can_edit_blog_topic?(admin_draft)).to eq(false)
    end

    it "denies topics outside the blog categories and category description topics" do
      drafts.update_columns(topic_id: admin_draft.id)

      expect(admin.guardian.can_edit_blog_topic?(Fabricate(:topic))).to eq(false)
      expect(admin.guardian.can_edit_blog_topic?(admin_draft)).to eq(false)
    end

    it "denies unlisted, deleted and shared draft topics" do
      unlisted = Fabricate(:topic, category: drafts, user: admin, visible: false)
      deleted = Fabricate(:topic, category: drafts, user: admin, deleted_at: Time.current)
      shared_draft = Fabricate(:topic, category: drafts, user: admin)
      SharedDraft.create!(topic: shared_draft, category: category)

      expect(admin.guardian.can_edit_blog_topic?(unlisted)).to eq(false)
      expect(admin.guardian.can_edit_blog_topic?(deleted)).to eq(false)
      expect(admin.guardian.can_edit_blog_topic?(shared_draft.reload)).to eq(false)
    end

    it "denies anonymous users" do
      expect(Guardian.new.can_edit_blog_topic?(article)).to eq(false)
    end
  end

  describe "#can_publish_blog_topic?" do
    it "allows publishers to publish an article they can edit" do
      expect(admin.guardian.can_publish_blog_topic?(writer_draft)).to eq(true)
    end

    it "denies editors" do
      expect(editor.guardian.can_publish_blog_topic?(admin_draft)).to eq(false)
    end

    it "denies publishers topics outside the blog categories" do
      expect(admin.guardian.can_publish_blog_topic?(Fabricate(:topic))).to eq(false)
    end
  end
end
