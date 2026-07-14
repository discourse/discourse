# frozen_string_literal: true

describe "discourse-solved admin dashboard highlight KPI" do
  def lookup_kpi
    DiscoursePluginRegistry.admin_dashboard_highlight_kpis.find do |kpi|
      kpi[:type] == :accepted_solutions
    end
  end

  before do
    SiteSetting.allow_solved_on_all_topics = false
    Discourse.cache.clear
  end

  after { Discourse.cache.clear }

  it "is registered with the plugin registry" do
    expect(lookup_kpi).to be_present
    expect(lookup_kpi[:report]).to eq("accepted_solutions")
  end

  describe "enabled lambda" do
    it "returns false when no category opts in and the global setting is off" do
      expect(lookup_kpi[:enabled].call).to eq(false)
    end

    it "returns true when allow_solved_on_all_topics is enabled" do
      SiteSetting.allow_solved_on_all_topics = true

      expect(lookup_kpi[:enabled].call).to eq(true)
    end

    it "returns true when at least one category opts in via custom field" do
      category = Fabricate(:category)
      CategoryCustomField.create!(
        category_id: category.id,
        name: DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD,
        value: "true",
      )

      expect(lookup_kpi[:enabled].call).to eq(true)
    end
  end
end
