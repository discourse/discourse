# frozen_string_literal: true

RSpec.describe WebArtifact do
  fab!(:user)
  fab!(:post)

  describe "validations" do
    it "enforces html max length" do
      artifact = Fabricate.build(:web_artifact, html: "a" * 65_536)
      expect(artifact).not_to be_valid
    end

    it "enforces css max length" do
      artifact = Fabricate.build(:web_artifact, css: "a" * 65_536)
      expect(artifact).not_to be_valid
    end

    it "enforces js max length" do
      artifact = Fabricate.build(:web_artifact, js: "a" * 65_536)
      expect(artifact).not_to be_valid
    end
  end

  describe "#create_new_version" do
    fab!(:artifact, :web_artifact)

    it "creates a new version with correct version_number" do
      version = artifact.create_new_version(html: "<p>v1</p>", change_description: "first change")

      expect(version.version_number).to eq(1)
      expect(version.html).to eq("<p>v1</p>")
      expect(version.change_description).to eq("first change")
    end

    it "increments version numbers" do
      artifact.create_new_version(html: "<p>v1</p>")
      version2 = artifact.create_new_version(html: "<p>v2</p>")

      expect(version2.version_number).to eq(2)
    end

    it "uses artifact values when none provided" do
      version = artifact.create_new_version

      expect(version.html).to eq(artifact.html)
      expect(version.css).to eq(artifact.css)
      expect(version.js).to eq(artifact.js)
    end
  end

  describe "#public?" do
    it "returns false by default" do
      artifact = Fabricate(:web_artifact)
      expect(artifact.public?).to eq(false)
    end

    it "returns true when metadata has public: true" do
      artifact = Fabricate(:web_artifact, metadata: { "public" => true })
      expect(artifact.public?).to eq(true)
    end
  end

  describe ".share_publicly" do
    fab!(:topic)
    fab!(:topic_post) { Fabricate(:post, topic: topic) }
    fab!(:artifact) { Fabricate(:web_artifact, post: topic_post) }

    it "marks artifact as public when post is in the same topic" do
      WebArtifact.share_publicly(id: artifact.id, post: topic_post)
      artifact.reload
      expect(artifact.public?).to eq(true)
    end

    it "does not mark artifact as public when post is in a different topic" do
      other_post = Fabricate(:post)
      WebArtifact.share_publicly(id: artifact.id, post: other_post)
      artifact.reload
      expect(artifact.public?).to eq(false)
    end
  end

  describe ".url" do
    it "returns the correct URL" do
      expect(WebArtifact.url(42)).to eq("#{Discourse.base_url}/w/42")
    end

    it "includes version when provided" do
      expect(WebArtifact.url(42, 3)).to eq("#{Discourse.base_url}/w/42/3")
    end
  end

  describe ".link_artifacts_from_cooked" do
    fab!(:post_for_linking, :post) { Fabricate(:post, user: user) }
    fab!(:artifact) { Fabricate(:web_artifact, user: user, post: nil) }

    it "links unlinked artifacts referenced in cooked HTML" do
      doc =
        Nokogiri::HTML5.fragment(
          "<div class='web-artifact' data-web-artifact-id='#{artifact.id}'></div>",
        )

      WebArtifact.link_artifacts_from_cooked(doc, post_for_linking)
      artifact.reload
      expect(artifact.post_id).to eq(post_for_linking.id)
    end

    it "links artifacts with ai-artifact class name" do
      doc =
        Nokogiri::HTML5.fragment(
          "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
        )

      WebArtifact.link_artifacts_from_cooked(doc, post_for_linking)
      artifact.reload
      expect(artifact.post_id).to eq(post_for_linking.id)
    end

    it "does not link artifacts owned by a different user" do
      other_user = Fabricate(:user)
      other_artifact = Fabricate(:web_artifact, user: other_user, post: nil)

      doc =
        Nokogiri::HTML5.fragment(
          "<div class='web-artifact' data-web-artifact-id='#{other_artifact.id}'></div>",
        )

      WebArtifact.link_artifacts_from_cooked(doc, post_for_linking)
      other_artifact.reload
      expect(other_artifact.post_id).to be_nil
    end

    it "does not re-link already linked artifacts" do
      existing_post = Fabricate(:post)
      linked_artifact = Fabricate(:web_artifact, user: user, post: existing_post)

      doc =
        Nokogiri::HTML5.fragment(
          "<div class='web-artifact' data-web-artifact-id='#{linked_artifact.id}'></div>",
        )

      WebArtifact.link_artifacts_from_cooked(doc, post_for_linking)
      linked_artifact.reload
      expect(linked_artifact.post_id).to eq(existing_post.id)
    end
  end
end
