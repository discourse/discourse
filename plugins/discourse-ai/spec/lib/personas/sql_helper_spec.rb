# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::SqlHelper do
  let(:sql_helper) { subject }

  before { enable_current_plugin }

  it "renders schema" do
    prompt = sql_helper.system_prompt
    expect(prompt).to include("posts(")
    expect(prompt).to include("topics(")
    expect(prompt).not_to include("translation_key") # not a priority table
    expect(prompt).to include("user_api_keys") # not a priority table

    expect(sql_helper.tools).to eq([DiscourseAi::Personas::Tools::DbSchema])
  end
end
