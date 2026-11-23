# frozen_string_literal: true

RSpec.describe "Blog managed categories", type: :request do
  fab!(:admin)
  fab!(:writers, :group)
  fab!(:writer) { Fabricate(:user, groups: [writers], refresh_auto_groups: true) }
  fab!(:member, :user)

  before do
    enable_blog!
    SiteSetting.blog_contributor_groups = writers.id.to_s
  end

  def draft_topic_for(user)
    drafts = Blog::EnsureDraftsCategory.call![:category]
    topic = Fabricate(:topic, category: drafts, user:)
    Fabricate(:post, topic:, user:, raw: "An article written before the blog had categories.")
    topic
  end

  describe "POST /blog-editor/drafts-category" do
    it "requires a blog role" do
      post "/blog-editor/drafts-category.json"
      expect(response.status).to eq(403)

      sign_in(member)
      post "/blog-editor/drafts-category.json"
      expect(response.status).to eq(403)
      expect(SiteSetting.blog_drafts_category).to be_blank
    end

    it "creates the private drafts category on first use and returns it for the composer" do
      sign_in(writer)

      expect { post "/blog-editor/drafts-category.json" }.to change { Category.count }.by(1)

      expect(response.status).to eq(200)
      drafts = Category.find(SiteSetting.blog_drafts_category)
      expect(drafts).to have_attributes(
        name: I18n.t("blog.categories.drafts"),
        read_restricted: true,
      )
      expect(response.parsed_body).to include(
        "id" => drafts.id,
        "name" => drafts.name,
        "permission" => CategoryGroup.permission_types[:full],
      )
      expect(member.guardian.can_see?(drafts)).to eq(false)
    end

    it "refuses to use a drafts category that is open to everyone" do
      drafts = Blog::EnsureDraftsCategory.call![:category]
      drafts.set_permissions(everyone: :full)
      drafts.save!
      sign_in(writer)

      post "/blog-editor/drafts-category.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("blog.errors.drafts_category_public"),
      )
      expect(drafts.reload.read_restricted).to eq(false)
    end
  end

  describe "POST /blog-editor/publications/:topic_id/publish" do
    it "creates the public category with the first article and reuses it afterwards" do
      first_topic = draft_topic_for(writer)
      second_topic = draft_topic_for(writer)
      sign_in(admin)

      expect { post "/blog-editor/publications/#{first_topic.id}/publish.json" }.to change {
        Category.count
      }.by(1)

      expect(response.status).to eq(200)
      blog_category = Category.find(Blog::Instance.default_blog.category_id)
      expect(blog_category).to have_attributes(
        name: I18n.t("blog.categories.public"),
        read_restricted: false,
      )
      expect(Blog::Publication.find_by!(topic: first_topic).discussion_topic.category).to eq(
        blog_category,
      )
      expect(member.guardian.can_create_topic_on_category?(blog_category)).to eq(false)

      expect { post "/blog-editor/publications/#{second_topic.id}/publish.json" }.not_to change {
        Category.count
      }
      expect(Blog::Publication.find_by!(topic: second_topic).discussion_topic.category).to eq(
        blog_category,
      )
    end

    it "refuses to adopt an existing category with the default name" do
      existing = Fabricate(:category, name: I18n.t("blog.categories.public"))
      topic = draft_topic_for(writer)
      sign_in(admin)

      post "/blog-editor/publications/#{topic.id}/publish.json"

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include(
        I18n.t("blog.errors.category_name_taken", name: existing.name),
      )
      expect(Blog::Instance.default_blog.category_id).to be_nil
      expect(Blog::Publication.find_by(topic:)&.discussion_topic).to be_nil
    end
  end

  describe "POST /blog-editor/publications/:topic_id/prepare" do
    fab!(:blog_category, :category)

    before { update_default_blog(category_id: blog_category.id) }

    it "creates the drafts category for the working copy of an existing topic" do
      topic = Fabricate(:topic, category: blog_category, user: writer)
      Fabricate(:post, topic:, user: writer, raw: "A topic that becomes an article.")
      sign_in(admin)

      post "/blog-editor/publications/#{topic.id}/prepare.json"

      expect(response.status).to eq(200)
      drafts = Category.find(SiteSetting.blog_drafts_category)
      expect(Blog::Publication.find_by!(topic:).draft_topic.category).to eq(drafts)
    end
  end

  describe "editorial work on a drafts category that is open to everyone" do
    fab!(:topic) { draft_topic_for(writer) }

    before do
      drafts = topic.category
      SiteSetting.blog_drafts_category = drafts.id
      drafts.set_permissions(everyone: :full)
      drafts.save!
      sign_in(writer)
    end

    it "does not submit the draft or change the category" do
      post "/blog-editor/publications/#{topic.id}/submit.json"

      expect(response.status).to eq(400)
      expect(response.parsed_body["errors"].first).to include(
        I18n.t("blog.errors.drafts_category_public"),
      )
      expect(topic.category.reload.read_restricted).to eq(false)
    end

    it "does not issue a review link" do
      expect { post "/blog-editor/publications/#{topic.id}/reviews.json" }.not_to change {
        Blog::Review.count
      }
      expect(response.status).not_to eq(201)
    end
  end
end
