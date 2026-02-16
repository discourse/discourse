# frozen_string_literal: true

RSpec.describe AiSecret do
  fab!(:ai_secret)

  describe "validations" do
    it "requires a name" do
      secret = AiSecret.new(secret: "test")
      expect(secret).not_to be_valid
      expect(secret.errors[:name]).to be_present
    end

    it "requires a secret" do
      secret = AiSecret.new(name: "test")
      expect(secret).not_to be_valid
      expect(secret.errors[:secret]).to be_present
    end

    it "requires unique name" do
      AiSecret.create!(name: "unique-name", secret: "test")
      duplicate = AiSecret.new(name: "unique-name", secret: "other")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it "enforces max name length" do
      secret = AiSecret.new(name: "a" * 101, secret: "test")
      expect(secret).not_to be_valid
    end
  end

  describe "#in_use?" do
    it "returns false when not referenced" do
      expect(ai_secret.in_use?).to eq(false)
    end

    it "returns true when used by an llm_model" do
      Fabricate(:llm_model, ai_secret: ai_secret)
      expect(ai_secret.in_use?).to eq(true)
    end

    it "returns true when used by an embedding_definition" do
      Fabricate(:embedding_definition, ai_secret: ai_secret)
      expect(ai_secret.in_use?).to eq(true)
    end

    it "returns true when referenced in provider_params as string" do
      Fabricate(
        :llm_model,
        provider: "aws_bedrock",
        url: "",
        provider_params: {
          region: "us-east-1",
          access_key_id: ai_secret.id.to_s,
        },
      )
      expect(ai_secret.in_use?).to eq(true)
    end

    it "returns true when referenced in provider_params as numeric" do
      llm = Fabricate(:bedrock_model)
      DB.exec(
        <<~SQL,
        UPDATE llm_models SET provider_params = :params::jsonb WHERE id = :id
      SQL
        id: llm.id,
        params: { region: "us-east-1", access_key_id: ai_secret.id }.to_json,
      )
      expect(ai_secret.in_use?).to eq(true)
    end

    it "does not false-match unrelated provider_params values" do
      other_secret = Fabricate(:ai_secret)
      Fabricate(
        :llm_model,
        provider: "aws_bedrock",
        url: "",
        provider_params: {
          region: "us-east-1",
          access_key_id: other_secret.id.to_s,
        },
      )
      expect(ai_secret.in_use?).to eq(false)
    end
  end

  describe "ai_secret_id existence validation" do
    it "rejects non-existent ai_secret_id on LlmModel" do
      llm = Fabricate.build(:llm_model, api_key: nil, ai_secret_id: -999)
      expect(llm).not_to be_valid
      expect(llm.errors[:ai_secret_id]).to be_present
    end

    it "rejects non-existent ai_secret_id on EmbeddingDefinition" do
      embedding = Fabricate.build(:embedding_definition, api_key: nil, ai_secret_id: -999)
      expect(embedding).not_to be_valid
      expect(embedding.errors[:ai_secret_id]).to be_present
    end

    it "accepts valid ai_secret_id on LlmModel" do
      llm = Fabricate.build(:llm_model, api_key: nil, ai_secret: ai_secret)
      expect(llm).to be_valid
    end
  end

  describe "#used_by" do
    it "lists all models using this secret" do
      llm = Fabricate(:llm_model, ai_secret: ai_secret)
      embedding = Fabricate(:embedding_definition, ai_secret: ai_secret)

      usage = ai_secret.used_by
      expect(usage.length).to eq(2)
      expect(usage.map { |u| u[:type] }).to contain_exactly("llm", "embedding")
    end
  end
end
