# frozen_string_literal: true

RSpec.describe DiscourseGifs do
  describe ".component_installed?" do
    it "returns false when no discourse-gifs theme component exists" do
      expect(described_class.component_installed?).to eq(false)
    end

    it "returns true when the component is installed via the canonical URL" do
      remote_theme = RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-gifs")
      Fabricate(:theme, component: true, remote_theme: remote_theme)

      expect(described_class.component_installed?).to eq(true)
    end

    it "returns true when the component is installed via the .git URL" do
      remote_theme =
        RemoteTheme.create!(remote_url: "https://github.com/discourse/discourse-gifs.git")
      Fabricate(:theme, component: true, remote_theme: remote_theme)

      expect(described_class.component_installed?).to eq(true)
    end

    it "returns true when installed via the author's repo" do
      remote_theme = RemoteTheme.create!(remote_url: "https://github.com/xfalcox/discourse-gifs")
      Fabricate(:theme, component: true, remote_theme: remote_theme)

      expect(described_class.component_installed?).to eq(true)
    end

    it "returns false for forks or similarly-named repos that the migration task would not match" do
      remote_theme = RemoteTheme.create!(remote_url: "https://github.com/myorg/discourse-gifs.git")
      Fabricate(:theme, component: true, remote_theme: remote_theme)

      expect(described_class.component_installed?).to eq(false)
    end
  end
end
