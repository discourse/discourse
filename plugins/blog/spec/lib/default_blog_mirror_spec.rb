# frozen_string_literal: true

RSpec.describe Blog::DefaultBlogMirror do
  describe ".sync!" do
    subject(:sync) { described_class.sync! }

    let(:default_blog) { Blog::Instance.find_by(is_default: true) }

    it "creates the default blog from the blog settings and the active theme" do
      category = Fabricate(:category)
      SiteSetting.blog_title = "Field notes"
      SiteSetting.blog_description = "Notes from the field."
      SiteSetting.blog_about = "Written by the field team."
      SiteSetting.blog_url = "https://notes.example.com"
      SiteSetting.blog_category = category.id
      SiteSetting.blog_path_format = "/{year}/{slug}"
      SiteSetting.blog_posts_per_page = 5
      PluginStore.set(Blog::BlogTheme::STORE, "active", { "id" => "ledger", "preset" => true })
      Blog::Instance.delete_all

      sync

      expect(Blog::Instance.sole).to have_attributes(
        name: "Field notes",
        description: "Notes from the field.",
        about: "Written by the field team.",
        slug: "blog",
        url: "https://notes.example.com",
        category_id: category.id,
        path_format: "/{year}/{slug}",
        posts_per_page: 5,
        active_theme: {
          "id" => "ledger",
          "preset" => true,
        },
        is_default: true,
      )
    end

    it "updates the existing default blog and keeps the fields it does not mirror" do
      described_class.sync!
      default_blog.update_columns(name: "Stale", slug: "main", position: 3)

      expect { sync }.not_to change { Blog::Instance.count }
      expect(default_blog.reload).to have_attributes(
        name: SiteSetting.blog_title,
        slug: "main",
        position: 3,
      )
    end

    it "copies the value a setting has once overridden in the environment" do
      SiteSetting.stubs(:blog_url).returns("https://env.example.com")

      sync

      expect(default_blog.url).to eq("https://env.example.com")
    end
  end
end
