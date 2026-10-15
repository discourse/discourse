# frozen_string_literal: true

RSpec.describe "View GitHub PR status" do
  fab!(:topic)

  let(:onebox) { PageObjects::Components::GithubOnebox.new }
  let(:statuses) { %w[open draft approved changes_requested merged closed] }

  before do
    enable_current_plugin
    SiteSetting.github_pr_status_enabled = true

    cooked =
      statuses
        .map
        .with_index do |status, index|
          url = "https://github.com/discourse/discourse/pull/#{index + 1}"
          response = MultiJson.load(onebox_response("githubpullrequest"))
          response.merge!(
            "state" => status == "closed" ? "closed" : "open",
            "merged" => status == "merged",
            "draft" => status == "draft",
            "merged_at" => "2026-10-15T06:00:00Z",
            "closed_at" => "2026-10-15T06:00:00Z",
            "body" => nil,
          )
          reviews =
            if %w[approved changes_requested].include?(status)
              [
                {
                  "user" => {
                    "id" => 1,
                  },
                  "state" => status.upcase,
                  "submitted_at" => "2026-10-15T06:00:00Z",
                },
              ]
            else
              []
            end
          api_url = "https://api.github.com/repos/discourse/discourse/pulls/#{index + 1}"
          stub_request(:get, api_url).to_return(body: MultiJson.dump(response))
          stub_request(:get, "#{api_url}/reviews").to_return(body: MultiJson.dump(reviews))

          Onebox::Engine::GithubPullRequestOnebox.new(url).to_html
        end
        .join

    Fabricate(:post, topic: topic, cooked: cooked)
  end

  it "shows readers a compact pill for each PR status" do
    visit "/t/#{topic.slug}/#{topic.id}"

    statuses.each { |status| expect(onebox).to have_status(status) }
    expect(onebox).to have_no_large_pr_icons
  end
end
