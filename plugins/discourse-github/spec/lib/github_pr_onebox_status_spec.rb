# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubPullRequestOnebox do
  let(:gh_link) { "https://github.com/discourse/discourse/pull/1253/" }
  let(:api_uri) { "https://api.github.com/repos/discourse/discourse/pulls/1253" }
  let(:reviews_api_uri) { "#{api_uri}/reviews" }

  def open_pr_response
    resp = MultiJson.load(onebox_response("githubpullrequest"))
    resp["state"] = "open"
    resp["merged"] = false
    resp["draft"] = false
    resp
  end

  before { enable_current_plugin }

  def onebox_html
    Onebox::Engine::GithubPullRequestOnebox.new(gh_link).to_html
  end

  describe "PR status" do
    context "when github_pr_status_enabled is false" do
      before do
        SiteSetting.github_pr_status_enabled = false
        stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
      end

      it "does not include status class" do
        expect(onebox_html).not_to include("--gh-status-")
      end
    end

    context "when github_pr_status_enabled is true" do
      before { SiteSetting.github_pr_status_enabled = true }

      context "with open PR" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: "[]")
        end

        it "includes open status" do
          expect(onebox_html).to include("--gh-status-open")
        end
      end

      context "when PR is merged" do
        before do
          resp = open_pr_response
          resp["merged"] = true
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: "[]")
        end

        it "includes merged status" do
          expect(onebox_html).to include("--gh-status-merged")
        end
      end

      context "when PR is closed" do
        before do
          resp = open_pr_response
          resp["state"] = "closed"
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: "[]")
        end

        it "includes closed status" do
          expect(onebox_html).to include("--gh-status-closed")
        end
      end

      context "when PR is draft" do
        before do
          resp = open_pr_response
          resp["draft"] = true
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: "[]")
        end

        it "includes draft status" do
          expect(onebox_html).to include("--gh-status-draft")
        end
      end

      context "when PR is approved" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            { "user" => { "id" => 1 }, "state" => "APPROVED", "submitted_at" => Time.now.iso8601 },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "includes approved status" do
          expect(onebox_html).to include("--gh-status-approved")
        end
      end

      context "when PR has changes requested" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            {
              "user" => {
                "id" => 1,
              },
              "state" => "CHANGES_REQUESTED",
              "submitted_at" => Time.now.iso8601,
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "includes changes_requested status" do
          expect(onebox_html).to include("--gh-status-changes_requested")
        end
      end

      context "when PR has both approval and changes requested from different reviewers" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            { "user" => { "id" => 1 }, "state" => "APPROVED", "submitted_at" => Time.now.iso8601 },
            {
              "user" => {
                "id" => 2,
              },
              "state" => "CHANGES_REQUESTED",
              "submitted_at" => Time.now.iso8601,
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "shows changes_requested (takes priority over approved)" do
          expect(onebox_html).to include("--gh-status-changes_requested")
          expect(onebox_html).not_to include("--gh-status-approved")
        end
      end

      context "when reviewer first requests changes then approves" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            {
              "user" => {
                "id" => 1,
              },
              "state" => "CHANGES_REQUESTED",
              "submitted_at" => "2024-01-01T00:00:00Z",
            },
            {
              "user" => {
                "id" => 1,
              },
              "state" => "APPROVED",
              "submitted_at" => "2024-01-02T00:00:00Z",
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "shows approved (latest review wins)" do
          expect(onebox_html).to include("--gh-status-approved")
          expect(onebox_html).not_to include("--gh-status-changes_requested")
        end
      end

      context "when reviews API fails" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          stub_request(:get, reviews_api_uri).to_return(status: 500, body: "error")
        end

        it "falls back gracefully without status" do
          expect(onebox_html).not_to include("--gh-status-")
        end
      end
    end
  end
end
