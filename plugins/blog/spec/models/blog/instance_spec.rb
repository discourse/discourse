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

    it "allows only one default blog" do
      described_class.where(is_default: true).delete_all
      described_class.create!(name: "Main", slug: "main", is_default: true)
      blog.is_default = true

      expect(blog).not_to be_valid
      expect(blog.errors).to include(:is_default)
    end
  end
end
