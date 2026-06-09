# frozen_string_literal: true

RSpec.describe AiArtifact do
  fab!(:user)
  fab!(:post_for_linking) { Fabricate(:post, user: user) }
  fab!(:artifact) { Fabricate(:ai_artifact, user: user, post: nil) }

  before { enable_current_plugin }

  describe ".link_artifacts_from_cooked" do
    let(:doc) do
      Nokogiri::HTML5.fragment(
        "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
      )
    end

    it "links unlinked artifacts owned by the post author" do
      AiArtifact.link_artifacts_from_cooked(doc, post_for_linking)

      expect(artifact.reload.post_id).to eq(post_for_linking.id)
    end

    it "leaves artifacts owned by another user not associated to a post" do
      artifact.update!(user: Fabricate(:user))

      AiArtifact.link_artifacts_from_cooked(doc, post_for_linking)

      expect(artifact.reload.post_id).to be_nil
    end

    it "leaves already-linked artifacts pointing at their original post" do
      original_post = Fabricate(:post)
      artifact.update!(post: original_post)

      AiArtifact.link_artifacts_from_cooked(doc, post_for_linking)

      expect(artifact.reload.post_id).to eq(original_post.id)
    end
  end
end
