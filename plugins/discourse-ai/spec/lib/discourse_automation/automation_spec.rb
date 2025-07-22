# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Automation do
  before { enable_current_plugin }

  describe "manually configured model" do
    let!(:llm_model) { Fabricate(:llm_model) }
    it "returns a list of available models for automation" do
      models = DiscourseAi::Automation.available_models
      expect(models).to be_an(Array)
      expect(models.first["translated_name"]).to eq(llm_model.display_name)
    end
  end

  describe "no models" do
    it "returns an empty list" do
      models = DiscourseAi::Automation.available_models
      expect(models).to be_empty
    end
  end

  describe "seeded models" do
    let!(:llm_model) { Fabricate(:seeded_model) }
    it "returns an empty list if no seeded models are allowed" do
      models = DiscourseAi::Automation.available_models
      expect(models).to be_empty
    end

    it "returns a list of seeded models if allowed" do
      SiteSetting.ai_automation_allowed_seeded_models = llm_model.id.to_s
      models = DiscourseAi::Automation.available_models
      expect(models.first["translated_name"]).to eq(llm_model.display_name)
    end
  end

  describe "mixed models" do
    let!(:llm_model) { Fabricate(:llm_model) }
    let!(:seeded_model) { Fabricate(:seeded_model) }

    it "returns only the manually configured model if seeded is not allowed" do
      models = DiscourseAi::Automation.available_models
      expect(models.length).to eq(1)
      expect(models.first["translated_name"]).to eq(llm_model.display_name)
    end

    it "returns a list of seeded and custom models when seeded is allowed" do
      SiteSetting.ai_automation_allowed_seeded_models = seeded_model.id.to_s
      models = DiscourseAi::Automation.available_models

      expect(models).to match_array(
        [
          { "translated_name" => "#{llm_model.display_name}", "id" => "custom:#{llm_model.id}" },
          {
            "translated_name" => "#{seeded_model.display_name}",
            "id" => "custom:#{seeded_model.id}",
          },
        ],
      )
    end
  end
end
