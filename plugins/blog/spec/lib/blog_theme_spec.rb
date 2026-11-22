# frozen_string_literal: true

RSpec.describe Blog::BlogTheme do
  describe ".activate" do
    it "creates the default blog when the site has none yet" do
      Blog::Instance.delete_all
      Blog::Instance.clear_cache

      described_class.activate(
        Blog::ThemePresets.find("discourse-blog"),
        Blog::Instance.default_blog,
      )

      expect(Blog::Instance.sole).to have_attributes(
        is_default: true,
        active_theme: {
          "id" => "discourse-blog",
          "preset" => true,
        },
      )
    end
  end
end
