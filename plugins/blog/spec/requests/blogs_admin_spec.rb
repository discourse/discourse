# frozen_string_literal: true

RSpec.describe "Blogs admin", type: :request do
  fab!(:admin)
  fab!(:moderator)
  fab!(:category)

  before { enable_blog!(category:, custom_domain: false) }

  describe "GET /admin/plugins/blog/blogs.json" do
    it "lists the blogs with what the admin needs to manage them" do
      sign_in(admin)

      get "/admin/plugins/blog/blogs.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["can_add_blog"]).to eq(true)
      expect(response.parsed_body["blogs"]).to contain_exactly(
        include(
          "id" => Blog::Instance.default_blog.id,
          "is_default" => true,
          "category_id" => category.id,
          "base_url" => "#{Discourse.base_url}/blog",
          "problems" => [],
          "can_delete" => false,
        ),
      )
    end

    it "is for admins only" do
      sign_in(moderator)

      get "/admin/plugins/blog/blogs.json"

      expect(response.status).to eq(403)
    end
  end

  it "renders the admin app when a blogs page is reloaded" do
    sign_in(admin)
    id = Blog::Instance.default_blog.id

    %W[
      /admin/plugins/blog/blogs
      /admin/plugins/blog/blogs/new
      /admin/plugins/blog/blogs/#{id}/about
      /admin/plugins/blog/blogs/#{id}/settings
      /admin/plugins/blog/blogs/#{id}/theme
    ].each do |path|
      get path
      expect(response.status).to eq(200), path
      expect(response.body).to include("data-discourse-setup"), path
    end
  end

  describe "POST /admin/plugins/blog/blogs.json" do
    before { sign_in(admin) }

    it "adds an unpublished blog" do
      post "/admin/plugins/blog/blogs.json",
           params: {
             blog: {
               name: "Engineering",
               slug: "engineering",
             },
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body).to include("name" => "Engineering", "published" => false)
    end

    it "explains the site's limit" do
      SiteSetting.blog_max_instances = 1

      post "/admin/plugins/blog/blogs.json",
           params: {
             blog: {
               name: "Engineering",
               slug: "engineering",
             },
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("blog.errors.blog_limit", count: 1)])
    end

    it "names the field a refused value belongs to" do
      Blog::Instance.create!(name: "Engineering", slug: "engineering")

      post "/admin/plugins/blog/blogs.json", params: { blog: { name: "Eng", slug: "engineering" } }

      expect(response.status).to eq(422)
      expect(response.parsed_body.dig("extras", "field_errors")).to eq(
        "slug" => [I18n.t("blog.errors.blog_slug_in_use")],
      )
    end
  end

  describe "PUT /admin/plugins/blog/blogs/:id.json" do
    it "saves the fields sent from one tab" do
      sign_in(admin)

      put "/admin/plugins/blog/blogs/#{Blog::Instance.default_blog.id}.json",
          params: {
            blog: {
              name: "Field notes",
              path_format: "/{year}/{slug}",
            },
          }

      expect(response.status).to eq(200)
      expect(Blog::Instance.default_blog).to have_attributes(
        name: "Field notes",
        path_format: "/{year}/{slug}",
        category_id: category.id,
      )
    end
  end

  describe "DELETE /admin/plugins/blog/blogs/:id.json" do
    it "refuses to delete a blog that has articles" do
      blog = Blog::Instance.create!(name: "Engineering", slug: "engineering")
      Blog::Publication.create!(topic: Fabricate(:topic), blog:, path: "/story")
      sign_in(admin)

      delete "/admin/plugins/blog/blogs/#{blog.id}.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq([I18n.t("blog.errors.blog_has_articles")])

      get "/admin/plugins/blog/blogs/#{blog.id}.json"
      expect(response.parsed_body["can_delete"]).to eq(false)
    end
  end

  describe "an unpublished blog" do
    fab!(:engineering_category, :category)

    let!(:engineering) do
      Blog::Instance.create!(
        name: "Engineering",
        slug: "engineering",
        category: engineering_category,
        published: false,
      )
    end

    it "serves nothing to readers until it is published" do
      get "/blog/engineering"
      expect(response.status).to eq(404)
      expect(response.body).not_to include(engineering.name)
      expect(response.body).to include("#{Discourse.base_url}/blog/blog-theme.css")

      get "/blog/engineering/blog-theme.css"
      expect(response.status).to eq(200)

      engineering.update!(published: true)
      get "/blog/engineering"
      expect(response.status).to eq(200)
    end
  end
end
