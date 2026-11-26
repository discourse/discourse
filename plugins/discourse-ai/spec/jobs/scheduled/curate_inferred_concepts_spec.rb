# frozen_string_literal: true

RSpec.describe Jobs::CurateInferredConcepts do
  subject(:job) { described_class.new }

  fab!(:vector_def, :cloudflare_embedding_def)

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true
  end

  describe "#execute" do
    it "does nothing when inferred_concepts_enabled is false" do
      SiteSetting.inferred_concepts_enabled = false
      curator = instance_double(DiscourseAi::InferredConcepts::Curator)
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)
      allow(curator).to receive(:curate!)

      job.execute({})

      expect(curator).not_to have_received(:curate!)
    end

    it "does nothing when embeddings are disabled" do
      SiteSetting.ai_embeddings_enabled = false
      curator = instance_double(DiscourseAi::InferredConcepts::Curator)
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)
      allow(curator).to receive(:curate!)

      job.execute({})

      expect(curator).not_to have_received(:curate!)
    end

    it "runs Curator#curate! when both inferred concepts and embeddings are enabled" do
      curator = instance_double(DiscourseAi::InferredConcepts::Curator)
      allow(DiscourseAi::InferredConcepts::Curator).to receive(:new).and_return(curator)
      allow(curator).to receive(:curate!)

      job.execute({})

      expect(curator).to have_received(:curate!)
    end
  end
end
