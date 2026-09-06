# frozen_string_literal: true

describe DiscourseDataExplorer::AiQueryGenerator do
  it "uses tools for both validation and final structured submission" do
    agent = described_class.new

    expect(agent.tools).to include(
      DiscourseAi::Agents::Tools::DbSchema,
      DiscourseDataExplorer::Tools::FindQueries,
      DiscourseDataExplorer::Tools::RunSql,
      DiscourseDataExplorer::Tools::SubmitQuery,
    )
    expect(agent.response_format).to be_nil
    expect(agent.system_prompt).to include("submit_query")
  end

  it "instructs the agent to submit the exact validated SQL" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("After RunSql returns success, call submit_query next")
    expect(prompt).to include("Do not call RunSql again with identical SQL")
    expect(prompt).to include("use the exact SQL text from the final successful RunSql call")
    expect(prompt).to include("Include the `-- [params]` block")
    expect(prompt).to include("Do not add or remove LIMIT clauses")
  end

  it "frames non-technical community prompts as aggregate insight" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("## Request interpretation")
    expect(prompt).to include("Treat these as schema-aware requests")
    expect(prompt).to include("preserve explicit requirements")
    expect(prompt).to include("Non-technical prompts may ask in community or business language")
    expect(prompt).to include("Prefer aggregate metrics over listing individual users")
    expect(prompt).to include("replies and distinct contributors")
    expect(prompt).to include("non-staff, non-staged, non-system users")
    expect(prompt).to include("Signup, registration, and member-count queries MUST")
    expect(prompt).to include("u.staged IS FALSE")
    expect(prompt).to include("Do not create staff-vs-member comparisons")
    expect(prompt).to include(
      "If a trend is appropriate and the user does not specify a time grain",
    )
    expect(prompt).to include("Join through topics and categories")
    expect(prompt).to include("c.read_restricted IS FALSE")
  end

  it "starts the workflow with request classification" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("1. Classify the prompt as schema-aware or insight-oriented")
    expect(prompt).to include("decide the population, activity or outcome, and reporting grain")
    expect(prompt).to include("use find_queries")
    expect(prompt).to include("Treat them as inspiration")
    expect(prompt).to include("3. Use the schema tool")
    expect(prompt).to include(
      "Write SQL based on the request interpretation, relevant schema, and useful patterns",
    )
  end

  it "instructs list params to use Data Explorer IN syntax" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("column IN (:param)")
    expect(prompt).to include("Do NOT use `ANY(:param)`")
    expect(prompt).to include("Plural \"categories\" MUST use `int_list :category_ids`")
    expect(prompt).to include("((:param) IS NULL OR column IN (:param))")
    expect(prompt).to include("((:category_ids) IS NULL OR t.category_id IN (:category_ids))")
    expect(prompt).to include("((:tag_names) IS NULL OR tags.name IN (:tag_names))")
  end
end
