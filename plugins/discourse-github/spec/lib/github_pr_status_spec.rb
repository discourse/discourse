# frozen_string_literal: true

describe GithubPrStatus do
  let(:owner) { "discourse" }
  let(:repo) { "discourse" }
  let(:pr_number) { 123 }

  let(:pr_url) { "https://api.github.com/repos/#{owner}/#{repo}/pulls/#{pr_number}" }
  let(:reviews_url) { "https://api.github.com/repos/#{owner}/#{repo}/pulls/#{pr_number}/reviews" }

  before { enable_current_plugin }

  def stub_pr_response(body)
    stub_request(:get, pr_url).to_return(status: 200, body: body.to_json, headers: {})
  end

  def stub_reviews_response(body)
    stub_request(:get, reviews_url).to_return(status: 200, body: body.to_json, headers: {})
  end

  describe ".fetch" do
    it "returns 'merged' when the PR is merged" do
      stub_pr_response({ "merged" => true, "state" => "closed" })

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("merged")
    end

    it "returns 'closed' when the PR is closed but not merged" do
      stub_pr_response({ "merged" => false, "state" => "closed" })

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("closed")
    end

    it "returns 'draft' when the PR is a draft" do
      stub_pr_response({ "merged" => false, "state" => "open", "draft" => true })

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("draft")
    end

    it "returns 'approved' when the PR has only approved reviews" do
      stub_pr_response({ "merged" => false, "state" => "open", "draft" => false })
      stub_reviews_response(
        [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "APPROVED",
            "submitted_at" => "2024-01-01T00:00:00Z",
          },
        ],
      )

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("approved")
    end

    it "returns 'open' when the PR has no reviews" do
      stub_pr_response({ "merged" => false, "state" => "open", "draft" => false })
      stub_reviews_response([])

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("open")
    end

    it "returns 'open' when the PR has changes requested" do
      stub_pr_response({ "merged" => false, "state" => "open", "draft" => false })
      stub_reviews_response(
        [
          {
            "user" => {
              "id" => 1,
            },
            "state" => "CHANGES_REQUESTED",
            "submitted_at" => "2024-01-01T00:00:00Z",
          },
        ],
      )

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to eq("open")
    end

    it "returns nil when the API request fails" do
      stub_request(:get, pr_url).to_return(status: 404, body: "", headers: {})

      expect(GithubPrStatus.fetch(owner, repo, pr_number)).to be_nil
    end
  end

  describe ".approved?" do
    it "returns false when reviews is empty" do
      expect(GithubPrStatus.send(:approved?, [])).to eq(false)
    end

    it "returns false when reviews is nil" do
      expect(GithubPrStatus.send(:approved?, nil)).to eq(false)
    end

    it "returns true when all reviews are approved" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
        {
          "user" => {
            "id" => 2,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(true)
    end

    it "returns true when reviews are approved or dismissed with at least one approval" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
        {
          "user" => {
            "id" => 2,
          },
          "state" => "DISMISSED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(true)
    end

    it "returns false when all reviews are dismissed" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "DISMISSED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(false)
    end

    it "returns false when any review requests changes" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
        {
          "user" => {
            "id" => 2,
          },
          "state" => "CHANGES_REQUESTED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(false)
    end

    it "uses the latest review from each user" do
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
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(true)
    end

    it "ignores PENDING reviews" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
        { "user" => { "id" => 2 }, "state" => "PENDING", "submitted_at" => "2024-01-02T00:00:00Z" },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(true)
    end

    it "ignores COMMENTED reviews" do
      reviews = [
        {
          "user" => {
            "id" => 1,
          },
          "state" => "APPROVED",
          "submitted_at" => "2024-01-01T00:00:00Z",
        },
        {
          "user" => {
            "id" => 2,
          },
          "state" => "COMMENTED",
          "submitted_at" => "2024-01-02T00:00:00Z",
        },
      ]
      expect(GithubPrStatus.send(:approved?, reviews)).to eq(true)
    end
  end
end
