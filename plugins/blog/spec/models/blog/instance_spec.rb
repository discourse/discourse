# frozen_string_literal: true

RSpec.describe Blog::Instance do
  describe "validations" do
    subject(:blog) { described_class.new(name: "Engineering", slug: "engineering") }

    it "accepts lowercase words joined by hyphens as the slug" do
      expect(blog).to be_valid

      %w[Engineering eng_notes -engineering engineering- eng--notes].each do |slug|
        blog.slug = slug
        expect(blog).not_to be_valid
        expect(blog.errors).to include(:slug)
      end
    end

    it "treats a blank URL as no custom domain" do
      blog.url = ""

      expect(blog.url).to be_nil
      expect(blog).to be_valid
    end

    it "accepts only an HTTPS origin without a path as the URL" do
      blog.url = "https://notes.example.com:8443"
      expect(blog).to be_valid

      %w[
        http://notes.example.com
        https://notes.example.com/news
        https://Notes.example.com
      ].each do |url|
        blog.url = url
        expect(blog).not_to be_valid
        expect(blog.errors).to include(:url)
      end
    end

    it "rejects a path format the blog cannot route" do
      blog.path_format = "/{year}"

      expect(blog).not_to be_valid
      expect(blog.errors[:path_format]).to eq([I18n.t("blog.errors.path_format")])
    end

    it "keeps posts per page between 1 and 30" do
      [0, 31].each do |posts_per_page|
        blog.posts_per_page = posts_per_page
        expect(blog).not_to be_valid
        expect(blog.errors).to include(:posts_per_page)
      end
    end

    it "rejects a slug the blog's own routes or the main blog's articles use" do
      default_blog = described_class.find_by(is_default: true)
      publication =
        Blog::Publication.create!(topic: Fabricate(:topic), path: "/field-notes/day-one")
      publication.paths.create!(path: "/Field-Notes/day-one")

      {
        "feed" => "blog_slug_reserved",
        "archive" => "blog_slug_reserved",
        "field-notes" => "blog_slug_taken",
      }.each do |slug, error|
        blog.slug = slug
        expect(blog).not_to be_valid
        expect(blog.errors[:slug]).to eq([I18n.t("blog.errors.#{error}")])
      end
      expect(default_blog).to be_valid
    end

    it "rejects a slug the main blog's path format always puts first" do
      default_blog = described_class.find_by(is_default: true)
      { "/news/{slug}" => "news", "/{year}/{slug}" => "2026" }.each do |format, slug|
        default_blog.update!(path_format: format)
        blog.slug = slug
        expect(blog).not_to be_valid
        expect(blog.errors[:slug]).to eq([I18n.t("blog.errors.blog_slug_reserved")])
      end

      default_blog.update!(path_format: "/{slug}")
      blog.slug = "news"
      expect(blog).to be_valid
    end

    it "rejects the community's own hostname as a blog's domain" do
      blog.url = "https://#{Discourse.current_hostname}"

      expect(blog).not_to be_valid
      expect(blog.errors[:url]).to eq([I18n.t("blog.errors.blog_url_forum_host")])
    end

    it "allows only one default blog" do
      described_class.where(is_default: true).delete_all
      described_class.create!(name: "Main", slug: "main", is_default: true)
      blog.is_default = true

      expect(blog).not_to be_valid
      expect(blog.errors).to include(:is_default)
    end
  end

  describe ".default_blog" do
    it "reflects a saved change to the default blog" do
      described_class.default_blog
      described_class.find_by(is_default: true).update!(name: "Field notes")

      expect(described_class.default_blog.name).to eq("Field notes")
    end
  end

  describe ".category_ids" do
    it "lists the public category of every blog" do
      first_category = Fabricate(:category)
      second_category = Fabricate(:category)
      described_class.find_by(is_default: true).update!(category_id: first_category.id)
      described_class.create!(
        name: "Engineering",
        slug: "engineering",
        category_id: second_category.id,
      )

      expect(described_class.category_ids).to contain_exactly(first_category.id, second_category.id)
    end
  end
end
