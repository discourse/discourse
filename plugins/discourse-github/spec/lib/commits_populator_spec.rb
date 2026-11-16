# frozen_string_literal: true

describe DiscourseGithubPlugin::CommitsPopulator do
  subject(:populator) { described_class.new(repo) }

  let(:repo) { DiscourseGithubPlugin::GithubRepo.new(name: "discourse/discourse") }
  let(:branches_url) { "https://api.github.com/repos/discourse/discourse/branches?per_page=1" }

  before { enable_current_plugin }

  it "logs GitHub API errors" do
    stub_request(:get, branches_url).to_return(status: 404)

    logger = track_log_messages { populator.populate! }

    expect(logger.warnings).to include(/NotFound/)
  end

  it "logs when GraphQL returns no data" do
    stub_request(:get, branches_url).to_return(status: 200, body: [{ name: "main" }].to_json)
    stub_request(:post, "https://api.github.com/graphql").to_return(
      status: 200,
      body: { message: "Bad credentials" }.to_json,
    )

    logger = track_log_messages { populator.populate! }

    expect(logger.warnings).to include(/GraphQLError/)
  end
end
