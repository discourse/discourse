# frozen_string_literal: true

describe DiscourseDataExplorer::AiQueryGenerator do
  it "uses tools for both validation and final structured submission" do
    agent = described_class.new

    expect(agent.tools).to include(
      DiscourseAi::Agents::Tools::DbSchema,
      DiscourseDataExplorer::Tools::RunSql,
      DiscourseDataExplorer::Tools::SubmitQuery,
    )
    expect(agent.response_format).to be_nil
    expect(agent.system_prompt).to include("submit_query")
  end
end
