# frozen_string_literal: true

RSpec.describe Blog::PathFormat do
  describe "#valid?" do
    it "accepts the presets and custom formats that keep each address unique" do
      formats = %w[
        /{slug}
        /{year}/{month}/{slug}
        /{year}/{month}/{day}/{slug}
        /news/{slug}
        /{year}/{id}
        /archives/{id}-{slug}
      ]

      expect(formats.reject { |format| described_class.new(format).valid? }).to be_empty
    end

    it "rejects formats that are unsafe, ambiguous or collide with blog routes" do
      formats = [
        "{slug}",
        "/{year}/{month}",
        "/{author}/{slug}",
        "/{slug}/",
        "/news//{slug}",
        "/news {slug}",
        "/tag/{slug}",
        "/news/../{slug}",
        "/./{slug}",
        "/#{"a" * 100}/{slug}",
      ]

      expect(formats.select { |format| described_class.new(format).valid? }).to be_empty
    end
  end

  it "guards the blog_path_format setting" do
    expect { SiteSetting.blog_path_format = "/{title}" }.to raise_error(
      Discourse::InvalidParameters,
    )
  end
end
