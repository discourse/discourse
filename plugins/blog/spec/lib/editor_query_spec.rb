# frozen_string_literal: true

RSpec.describe Blog::EditorQuery do
  fab!(:admin)
  fab!(:writers, :group)
  fab!(:editors, :group)
  fab!(:writer) { Fabricate(:user, groups: [writers]) }
  fab!(:editor) { Fabricate(:user, groups: [editors]) }
  fab!(:category)
  fab!(:drafts) do
    Fabricate(:private_category, group: Group[:staff]).tap do |drafts|
      drafts.set_permissions(:staff => :full, writers.name => :full)
      drafts.save!
    end
  end

  fab!(:draft) do
    Fabricate(:topic, category: drafts, user: admin, title: "Alpha draft for the editor")
  end
  fab!(:writer_draft) { Fabricate(:topic, category: drafts, user: writer) }
  fab!(:unpublished_article) { Fabricate(:topic, category: category, user: admin) }

  # A live article edited through a private working copy.
  fab!(:live_article) { Fabricate(:topic, category: category, user: admin) }
  fab!(:live_article_post) { Fabricate(:post, topic: live_article, user: admin) }
  fab!(:working_copy) do
    Fabricate(:topic, category: drafts, user: admin, title: "Working copy of the live article")
  end
  fab!(:live_publication) do
    Blog::Publication
      .create!(
        topic: live_article,
        discussion_topic: live_article,
        path: "/live-path",
        published: true,
        published_at: 1.day.ago,
      )
      .tap { |publication| publication.update!(draft_topic: working_copy) }
  end

  # A draft published into a separate public discussion topic.
  fab!(:source) { Fabricate(:topic, category: drafts, user: admin) }
  fab!(:source_post) { Fabricate(:post, topic: source, user: admin) }
  fab!(:discussion) { Fabricate(:topic, category: category, user: admin) }
  fab!(:discussion_post) { Fabricate(:post, topic: discussion, user: admin) }
  fab!(:source_publication) do
    Blog::Publication.create!(
      topic: source,
      draft_topic: source,
      discussion_topic: discussion,
      path: "/source-path",
      published: true,
      published_at: 1.day.ago,
    )
  end

  before do
    enable_blog!(category: category, drafts: drafts)
    SiteSetting.blog_contributor_groups = writers.id.to_s
    SiteSetting.blog_editor_groups = "#{Group::AUTO_GROUPS[:staff]}|#{editors.id}"
  end

  def topic_ids(guardian, **options)
    described_class.call(guardian, **options).pluck(:id)
  end

  describe ".call" do
    it "rejects unknown filters and malformed queries" do
      expect { described_class.call(admin.guardian, filter: "deleted") }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect { described_class.call(admin.guardian, query: ["alpha"]) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect {
        described_class.call(admin.guardian, query: "a" * (described_class::MAX_QUERY_LENGTH + 1))
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "lists each article once, by its editorial topic, within the blog categories" do
      outside = Fabricate(:topic, user: admin)
      description = Fabricate(:topic, category: category, user: admin)
      category.update_columns(topic_id: description.id)

      expect(topic_ids(admin.guardian)).to contain_exactly(
        draft.id,
        writer_draft.id,
        unpublished_article.id,
        live_article.id,
        source.id,
      )
      expect(topic_ids(admin.guardian)).not_to include(
        outside.id,
        description.id,
        working_copy.id,
        discussion.id,
      )
    end

    it "orders by most recent update, breaking ties by newest topic" do
      freeze_time
      tied = [writer_draft, unpublished_article, live_article, source]
      Topic.where(id: tied.map(&:id)).update_all(updated_at: 1.day.ago)
      draft.update_columns(updated_at: Time.current)

      expect(topic_ids(admin.guardian)).to eq([draft.id] + tied.map(&:id).sort.reverse)
    end

    it "limits contributors without the editor role to their own topics" do
      expect(topic_ids(writer.guardian)).to contain_exactly(writer_draft.id)
    end

    it "hides topics, and articles whose working copy, the user cannot see" do
      expect(topic_ids(editor.guardian)).to contain_exactly(unpublished_article.id)
    end

    it "lists private drafts, excluding the sources of published articles, for the drafts filter" do
      expect(topic_ids(admin.guardian, filter: "drafts")).to contain_exactly(
        draft.id,
        writer_draft.id,
      )
    end

    it "lists the source of an unpublished article again for the drafts filter" do
      source_publication.update_columns(published: false)

      expect(topic_ids(admin.guardian, filter: "drafts")).to contain_exactly(
        draft.id,
        writer_draft.id,
        source.id,
      )
    end

    it "lists publicly visible articles for the published filter" do
      expect(topic_ids(admin.guardian, filter: "published")).to contain_exactly(
        live_article.id,
        source.id,
      )
    end

    it "leaves scheduled articles out of the published filter" do
      live_publication.update_columns(published_at: 1.day.from_now)

      expect(topic_ids(admin.guardian, filter: "published")).to contain_exactly(source.id)
    end

    it "lists public topics that are not live, including scheduled articles, for the unpublished filter" do
      live_publication.update_columns(published_at: 1.day.from_now)

      expect(topic_ids(admin.guardian, filter: "unpublished")).to contain_exactly(
        unpublished_article.id,
        live_article.id,
      )
    end

    it "matches titles case-insensitively, ignoring surrounding whitespace" do
      expect(topic_ids(admin.guardian, query: "  ALPHA draft ")).to contain_exactly(draft.id)
    end

    it "matches topic slugs" do
      writer_draft.update_columns(slug: "distinctive-slug")

      expect(topic_ids(admin.guardian, query: "distinctive-slug")).to contain_exactly(
        writer_draft.id,
      )
    end

    it "matches live and staged article paths" do
      source_publication.update_columns(draft_metadata: { "path" => "/staged-path" })

      expect(topic_ids(admin.guardian, query: "live-path")).to contain_exactly(live_article.id)
      expect(topic_ids(admin.guardian, query: "staged-path")).to contain_exactly(source.id)
    end

    it "matches an article by its working copy's title" do
      expect(topic_ids(admin.guardian, query: "working copy")).to contain_exactly(live_article.id)
    end

    it "ignores a blank query" do
      expect(topic_ids(admin.guardian, query: "   ")).to match_array(topic_ids(admin.guardian))
    end

    it "applies the search within the selected filter" do
      expect(topic_ids(admin.guardian, filter: "published", query: "alpha")).to be_empty
      expect(topic_ids(admin.guardian, filter: "drafts", query: "alpha")).to contain_exactly(
        draft.id,
      )
    end
  end
end
