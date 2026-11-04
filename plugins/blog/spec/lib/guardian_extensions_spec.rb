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

  after { Thread.current[:blog_publishing_topic] = nil }

  def while_publishing(topic)
    Thread.current[:blog_publishing_topic] = topic.id
    yield
  ensure
    Thread.current[:blog_publishing_topic] = nil
  end

  describe "#can_edit_post?" do
    context "with the first post of a published article" do
      it "denies even admins outside of publishing" do
        expect(admin.guardian.can_edit_post?(article_post)).to eq(false)
      end

      it "allows a publisher while that topic is being published" do
        while_publishing(article) do
          expect(admin.guardian.can_edit_post?(article_post)).to eq(true)
        end
      end

      it "denies a publisher while a different topic is being published" do
        while_publishing(admin_draft) do
          expect(admin.guardian.can_edit_post?(article_post)).to eq(false)
        end
      end

      it "denies editors and anonymous users while the topic is being published" do
        while_publishing(article) do
          expect(editor.guardian.can_edit_post?(article_post)).to eq(false)
          expect(Guardian.new.can_edit?(article_post)).to eq(false)
        end
      end

      it "denies a publisher who cannot see the topic" do
        publishers = Fabricate(:group)
        publisher = Fabricate(:user, groups: [publishers])
        SiteSetting.blog_publisher_groups = publishers.id.to_s
        category.set_permissions(staff: :full)
        category.save!

        while_publishing(article) do
          expect(publisher.guardian.can_edit_post?(article_post)).to eq(false)
        end
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

      it "denies editors other members' topics when the drafts category is public" do
        pending "the editorial grant does not require a private drafts category"
        public_drafts = Fabricate(:category)
        member_topic = Fabricate(:topic, category: public_drafts)
        member_post = Fabricate(:post, topic: member_topic, user: member_topic.user)
        SiteSetting.blog_drafts_category = public_drafts.id

        expect(editor.guardian.can_edit_post?(member_post)).to eq(false)
      end
    end
  end

  describe "#can_edit_topic?" do
    context "with a published article's topic" do
      it "denies even admins outside of publishing" do
        expect(admin.guardian.can_edit_topic?(article)).to eq(false)
      end

      it "allows a publisher while that topic is being published" do
        while_publishing(article) { expect(admin.guardian.can_edit_topic?(article)).to eq(true) }
      end

      it "denies a publisher while a different topic is being published" do
        while_publishing(admin_draft) do
          expect(admin.guardian.can_edit_topic?(article)).to eq(false)
        end
      end

      it "denies editors and anonymous users while the topic is being published" do
        while_publishing(article) do
          expect(editor.guardian.can_edit_topic?(article)).to eq(false)
          expect(Guardian.new.can_edit?(article)).to eq(false)
        end
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
    end
  end
end
