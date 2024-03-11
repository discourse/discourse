# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubIssueOnebox do
  before do
    @link = "https://github.com/discourse/discourse/issues/1"

    stub_request(:get, "https://api.github.com/repos/discourse/discourse/issues/1").to_return(
      status: 200,
      body: onebox_response("github_issue_onebox"),
    )
  end

  include_context "with engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "sanitizes the input and transform the emoji into an img tag" do
      sanitized_label =
        'Test <img src="/images/emoji/twitter/+1.png?v=12" title="+1" class="emoji" alt="+1" loading="lazy" width="20" height="20">'

      expect(html).to include(sanitized_label)
    end
  end
end
