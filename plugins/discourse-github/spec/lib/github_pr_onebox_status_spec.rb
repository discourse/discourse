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

        it "includes open status and shows created_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-open")
          expect(html).to include(I18n.t("onebox.github.status_date.open"))
          expect(html).to include('data-date="2013-07-26"')
        end
      end

      context "when PR is merged" do
        before do
          resp = open_pr_response
          resp["merged"] = true
          resp["merged_at"] = "2024-02-15T10:30:00Z"
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
        end

        it "includes merged status and shows merged_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-merged")
          expect(html).to include(I18n.t("onebox.github.status_date.merged"))
          expect(html).to include('data-date="2024-02-15"')
        end
      end

      context "when PR is closed" do
        before do
          resp = open_pr_response
          resp["state"] = "closed"
          resp["closed_at"] = "2024-03-20T14:45:00Z"
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
        end

        it "includes closed status and shows closed_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-closed")
          expect(html).to include(I18n.t("onebox.github.status_date.closed"))
          expect(html).to include('data-date="2024-03-20"')
        end
      end

      context "when PR is draft" do
        before do
          resp = open_pr_response
          resp["draft"] = true
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(resp))
        end

        it "includes draft status and shows created_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-draft")
          expect(html).to include(I18n.t("onebox.github.status_date.draft"))
          expect(html).to include('data-date="2013-07-26"')
        end
      end

      context "when PR is approved" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            {
              "user" => {
                "id" => 1,
              },
              "state" => "APPROVED",
              "submitted_at" => "2024-04-10T09:15:00Z",
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "includes approved status and shows review submitted_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-approved")
          expect(html).to include(I18n.t("onebox.github.status_date.approved"))
          expect(html).to include('data-date="2024-04-10"')
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
              "submitted_at" => "2024-05-05T16:20:00Z",
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "includes changes_requested status and shows review submitted_at date" do
          html = onebox_html
          expect(html).to include("--gh-status-changes_requested")
          expect(html).to include(I18n.t("onebox.github.status_date.changes_requested"))
          expect(html).to include('data-date="2024-05-05"')
        end
      end

      context "when PR has both approval and changes requested from different reviewers" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          reviews = [
            {
              "user" => {
                "id" => 1,
              },
              "state" => "APPROVED",
              "submitted_at" => "2024-05-30T12:00:00Z",
            },
            {
              "user" => {
                "id" => 2,
              },
              "state" => "CHANGES_REQUESTED",
              "submitted_at" => "2024-06-01T12:00:00Z",
            },
          ]
          stub_request(:get, reviews_api_uri).to_return(status: 200, body: MultiJson.dump(reviews))
        end

        it "shows changes_requested status with its date (takes priority over approved)" do
          html = onebox_html
          expect(html).to include("--gh-status-changes_requested")
          expect(html).not_to include("--gh-status-approved")
          expect(html).to include(I18n.t("onebox.github.status_date.changes_requested"))
          expect(html).to include('data-date="2024-06-01"')
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

        it "shows approved status with latest review date (latest review wins)" do
          html = onebox_html
          expect(html).to include("--gh-status-approved")
          expect(html).not_to include("--gh-status-changes_requested")
          expect(html).to include(I18n.t("onebox.github.status_date.approved"))
          expect(html).to include('data-date="2024-01-02"')
        end
      end

      context "when reviews API fails" do
        before do
          stub_request(:get, api_uri).to_return(status: 200, body: MultiJson.dump(open_pr_response))
          stub_request(:get, reviews_api_uri).to_return(status: 500, body: "error")
        end

        it "falls back gracefully without status class and shows opened with created_at date" do
          html = onebox_html
          expect(html).not_to include("--gh-status-")
          expect(html).to include(I18n.t("onebox.github.status_date.open"))
          expect(html).to include('data-date="2013-07-26"')
        end
      end
    end
  end
end
