# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/migrate/20250125162658_fix_broken_open_ai_embeddings_config",
        )

RSpec.describe FixBrokenOpenAiEmbeddingsConfig do
  subject(:migration) { described_class.new }

  let(:connection) { ActiveRecord::Base.connection }

  def store_setting(name, val)
    connection.execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('#{name}', 3, '#{val}', NOW(), NOW())
    SQL
  end

  def configured_model_id
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = 'ai_embeddings_selected_model'",
    ).first
  end

  before { enable_current_plugin }

  describe "#up" do
    context "when embeddings are already configured" do
      fab!(:embedding_definition)

      before { store_setting("ai_embeddings_selected_model", embedding_definition.id) }

      it "does nothing" do
        migration.up

        expect(configured_model_id).to eq(embedding_definition.id.to_s)
      end
    end

    context "when there is no previous config" do
      it "does nothing" do
        migration.up

        expect(configured_model_id).to be_blank
      end
    end

    context "when things are not fully configured" do
      before do
        store_setting("ai_embeddings_model", "text-embedding-3-large")
        store_setting("ai_openai_api_key", "")
      end

      it "does nothing" do
        migration.up

        expect(configured_model_id).to be_blank
      end
    end

    context "when we have a configuration that previously failed to copy" do
      before do
        store_setting("ai_embeddings_model", "text-embedding-3-large")
        store_setting("ai_openai_api_key", "123")
      end

      it "copies the config" do
        migration.up

        embedding_def = EmbeddingDefinition.last

        expect(configured_model_id).to eq(embedding_def.id.to_s)
      end
    end
  end
end
