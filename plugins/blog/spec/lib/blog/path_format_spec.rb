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
        /%E3%83%8B%E3%83%A5%E3%83%BC%E3%82%B9/{slug}
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
        "/%E6{slug}",
        "/%E2%80%AE{slug}",
      ]

      expect(formats.select { |format| described_class.new(format).valid? }).to be_empty
    end
  end

  describe "#render" do
    it "never cuts an encoded slug partway through a character" do
      format = described_class.new("/{slug}")
      slug = "%E6%97%A5" * 20

      (10..30).each do |max_length|
        path = format.render(slug:, id: 1, date: Time.utc(2026, 1, 1), max_length:)

        expect(path).to match(%r{\A/(?:%E6%97%A5)*\z})
        expect(path.length).to be <= max_length
      end
    end
  end

  it "guards the blog_path_format setting" do
    expect { SiteSetting.blog_path_format = "/{title}" }.to raise_error(
      Discourse::InvalidParameters,
    )
  end
end
