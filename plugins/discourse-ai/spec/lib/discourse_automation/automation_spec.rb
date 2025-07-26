# frozen_string_literal: true

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

  describe "mixed models" do
    let!(:llm_model) { Fabricate(:llm_model) }
    let!(:seeded_model) { Fabricate(:seeded_model) }

    it "returns a list of seeded and custom models" do
      models = DiscourseAi::Automation.available_models

      expect(models).to match_array(
        [
          { "translated_name" => "#{llm_model.display_name}", "id" => llm_model.id.to_s },
          { "translated_name" => "#{seeded_model.display_name}", "id" => seeded_model.id.to_s },
        ],
      )
    end
  end
end
