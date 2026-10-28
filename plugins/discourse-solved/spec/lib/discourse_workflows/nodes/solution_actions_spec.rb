# frozen_string_literal: true

RSpec.shared_context "with a topic to solve" do
  fab!(:admin)
  fab!(:topic)
  fab!(:question) { Fabricate(:post, topic:) }
  fab!(:answer) { Fabricate(:post, topic:) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
  end

  def run_node(post_id: answer.id, actor_username: admin.username)
    execute_node(configuration: { "post_id" => post_id.to_s, "actor_username" => actor_username })
  end

  def solution_error(key, **args)
    "#{I18n.t("discourse_solved.discourse_workflows.solution_action.#{key}", **args)} [item 0]"
  end

  def accept(post)
    DiscourseSolved::AcceptAnswer.call(params: { post_id: post.id }, guardian: admin.guardian)
  end

  def solutions
    topic.reload.topic_answers.pluck(:answer_post_id)
  end
end

RSpec.describe DiscourseWorkflows::Nodes::AcceptSolution::V1 do
  include_context "with a topic to solve"

  it "accepts the post as the actor", :aggregate_failures do
    result = nil
    events = DiscourseEvent.track_events(:accepted_solution) { result = run_node }

    expect(result).to include(
      "post" => include("id" => answer.id),
      "actor" => include("id" => admin.id),
      "changed" => true,
    )
    expect(result).to match_node_output_schema(described_class)
    expect(solutions).to eq([answer.id])
    expect(events.sole[:params]).to eq([answer, { acting_user: admin }])
  end

  it "reports nothing changed for an accepted solution" do
    accept(answer)

    expect(run_node).to include("changed" => false)
  end

  it "refuses actors who can't accept, even when nothing would change" do
    accept(answer)
    user = Fabricate(:user)

    expect { run_node(actor_username: user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      solution_error("accept_not_allowed", username: user.username, post_id: answer.id.to_s),
    )
  end

  it "fails on a missing post" do
    expect { run_node(post_id: -1) }.to raise_error(
      DiscourseWorkflows::NodeError,
      solution_error("post_not_found", post_id: "-1"),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::UnacceptSolution::V1 do
  include_context "with a topic to solve"

  it "unaccepts the solution as the actor", :aggregate_failures do
    accept(answer)

    result = nil
    events = DiscourseEvent.track_events(:unaccepted_solution) { result = run_node }

    expect(result).to include("actor" => include("id" => admin.id), "changed" => true)
    expect(result).to match_node_output_schema(described_class)
    expect(solutions).to be_empty
    expect(events.sole[:params]).to eq([answer, { acting_user: admin }])
  end

  it "reports nothing changed for a post that isn't a solution" do
    expect(run_node).to include("changed" => false)
  end

  it "refuses actors who can't unaccept, even when nothing would change" do
    user = Fabricate(:user)

    expect { run_node(actor_username: user.username) }.to raise_error(
      DiscourseWorkflows::NodeError,
      solution_error("unaccept_not_allowed", username: user.username, post_id: answer.id.to_s),
    )
  end
end

RSpec.describe DiscourseWorkflows::Nodes::SolutionAccepted::V1 do
  include_context "with a topic to solve"

  it "fires only for its change, without a change key", :aggregate_failures do
    accepted = described_class.from_event(:accepted_solution, answer, acting_user: admin)
    unaccepted =
      DiscourseWorkflows::Nodes::SolutionUnaccepted::V1.from_event(
        :unaccepted_solution,
        answer,
        acting_user: admin,
      )

    expect(accepted).to be_valid
    expect(accepted.output).not_to have_key(:change)
    expect(accepted.output).to match_node_output_schema(described_class)
    expect(unaccepted).to be_valid
    expect(described_class.from_event(:unaccepted_solution, answer)).not_to be_valid
    expect(described_class.description[:event]).to eq(:accepted_solution)
  end

  it "hides the generic trigger from the palette" do
    expect(DiscourseWorkflows::Nodes::SolutionChanged::V1).not_to be_palette_visible
  end
end
