# frozen_string_literal: true

require "rails_helper"

describe GithubLinkback do
  let(:github_commit_link) do
    "https://github.com/discourse/discourse/commit/76981605fa10975e2e7af457e2f6a31909e0c811"
  end
  let(:github_commit_link_with_anchor) { "#{github_commit_link}#anchor" }
  let(:github_issue_link) { "https://github.com/discourse/discourse/issues/123" }
  let(:github_pr_link) { "https://github.com/discourse/discourse/pull/701" }
  let(:github_pr_files_link) { "https://github.com/discourse/discourse/pull/701/files" }
  let(:github_pr_link_wildcard) { "https://github.com/discourse/discourse-github-linkback/pull/3" }

  let(:post) { Fabricate(:post, raw: <<~RAW) }
        cool post

        #{github_commit_link}

        https://eviltrout.com/not-a-gh-link

        #{github_commit_link}

        #{github_commit_link_with_anchor}

        https://github.com/eviltrout/tis-100/commit/e22b23f354e3a1c31bc7ad37a6a309fd6daf18f4

        #{github_issue_link}

        #{github_pr_link}

        #{github_pr_files_link}

        i have no idea what i'm linking back to

        #{github_pr_link_wildcard}

        end_of_transmission

      RAW

  before { enable_current_plugin }

  describe "#should_enqueue?" do
    let(:post_without_link) { Fabricate.build(:post, raw: "Hello github!") }
    let(:small_action_post) do
      Fabricate.build(
        :post,
        post_type: Post.types[:small_action],
        raw:
          "https://github.com/discourse/discourse/commit/5be9bee2307dd517c26e6ef269471aceba5d5acf",
      )
    end
    let(:post_with_link) do
      Fabricate.build(
        :post,
        raw:
          "https://github.com/discourse/discourse/commit/5be9bee2307dd517c26e6ef269471aceba5d5acf",
      )
    end

    it "returns false when the feature is disabled" do
      SiteSetting.github_linkback_enabled = false
      expect(GithubLinkback.new(post_with_link).should_enqueue?).to eq(false)
    end

    it "returns false without a post" do
      SiteSetting.github_linkback_enabled = true
      expect(GithubLinkback.new(nil).should_enqueue?).to eq(false)
    end

    it "returns false if the post is not a regular post" do
      SiteSetting.github_linkback_enabled = true
      expect(GithubLinkback.new(small_action_post).should_enqueue?).to eq(false)
    end

    it "returns false when the post doesn't have the `github.com` in it" do
      SiteSetting.github_linkback_enabled = true
      expect(GithubLinkback.new(post_without_link).should_enqueue?).to eq(false)
    end

    it "returns true when the feature is enabled" do
      SiteSetting.github_linkback_enabled = true
      expect(GithubLinkback.new(post_with_link).should_enqueue?).to eq(true)
    end

    describe "private_message" do
      it "doesn't enqueue private messages" do
        SiteSetting.github_linkback_enabled = true
        private_topic = Fabricate(:private_message_topic)
        private_post =
          Fabricate(
            :post,
            topic: private_topic,
            raw: "this post http://github.com should not enqueue",
          )
        expect(GithubLinkback.new(private_post).should_enqueue?).to eq(false)
      end
    end

    describe "unlisted topics" do
      it "doesn't enqueue unlisted topics" do
        SiteSetting.github_linkback_enabled = true
        unlisted_topic = Fabricate(:topic, visible: false)
        unlisted_post =
          Fabricate(
            :post,
            topic: unlisted_topic,
            raw: "this post http://github.com should not enqueue",
          )
        expect(GithubLinkback.new(unlisted_post).should_enqueue?).to eq(false)
      end
    end
  end

  describe "#github_links" do
    it "returns an empty array with no projects" do
      SiteSetting.github_linkback_projects = ""
      links = GithubLinkback.new(post).github_links
      expect(links).to eq([])
    end

    it "doesn't return links that have already been posted" do
      SiteSetting.github_linkback_projects =
        "discourse/discourse|eviltrout/ember-performance|discourse/*"

      post.custom_fields[GithubLinkback.field_for(github_commit_link)] = "true"
      post.custom_fields[GithubLinkback.field_for(github_issue_link)] = "true"
      post.custom_fields[GithubLinkback.field_for(github_pr_link)] = "true"
      post.custom_fields[GithubLinkback.field_for(github_pr_link_wildcard)] = "true"
      post.save_custom_fields

      links = GithubLinkback.new(post).github_links
      expect(links.size).to eq(0)
    end

    it "should return the urls for the selected projects" do
      SiteSetting.github_linkback_projects =
        "discourse/discourse|eviltrout/ember-performance|discourse/*"
      links = GithubLinkback.new(post).github_links
      expect(links.size).to eq(4)

      expect(links[0].url).to eq(github_commit_link)
      expect(links[0].project).to eq("discourse/discourse")
      expect(links[0].sha).to eq("76981605fa10975e2e7af457e2f6a31909e0c811")
      expect(links[0].type).to eq(:commit)

      expect(links[1].url).to eq(github_issue_link)
      expect(links[1].project).to eq("discourse/discourse")
      expect(links[1].issue_number).to eq(123)
      expect(links[1].type).to eq(:issue)

      expect(links[2].url).to eq(github_pr_link)
      expect(links[2].project).to eq("discourse/discourse")
      expect(links[2].pr_number).to eq(701)
      expect(links[2].type).to eq(:pr)

      expect(links[3].url).to eq(github_pr_link_wildcard)
      expect(links[3].project).to eq("discourse/discourse-github-linkback")
      expect(links[3].pr_number).to eq(3)
      expect(links[3].type).to eq(:pr)
    end
  end

  describe "#create" do
    before { SiteSetting.github_linkback_projects = "discourse/discourse|discourse/*" }

    it "returns an empty array without an access token" do
      expect(GithubLinkback.new(post).create).to be_blank
    end

    context "with an access token" do
      let(:headers) do
        {
          "Authorization" => "token abcdef",
          "Content-Type" => "application/json",
          "Host" => "api.github.com",
          "User-Agent" => "Discourse-Github-Linkback",
        }
      end

      before do
        SiteSetting.github_linkback_access_token = "abcdef"

        stub_request(
          :post,
          "https://api.github.com/repos/discourse/discourse/commits/76981605fa10975e2e7af457e2f6a31909e0c811/comments",
        ).with(headers: headers).to_return(status: 200, body: "", headers: {})

        stub_request(
          :post,
          "https://api.github.com/repos/discourse/discourse/issues/123/comments",
        ).with(headers: headers).to_return(status: 200, body: "", headers: {})

        stub_request(
          :post,
          "https://api.github.com/repos/discourse/discourse/issues/701/comments",
        ).with(headers: headers).to_return(status: 200, body: "", headers: {})

        stub_request(
          :post,
          "https://api.github.com/repos/discourse/discourse-github-linkback/issues/3/comments",
        ).with(headers: headers).to_return(status: 200, body: "", headers: {})
      end

      it "returns the URLs it linked to and creates custom fields" do
        links = GithubLinkback.new(post).create
        expect(links.size).to eq(4)

        expect(links[0].url).to eq(github_commit_link)
        field = GithubLinkback.field_for(github_commit_link)
        expect(post.custom_fields[field]).to be_present

        expect(links[1].url).to eq(github_issue_link)
        field = GithubLinkback.field_for(github_issue_link)
        expect(post.custom_fields[field]).to be_present

        expect(links[2].url).to eq(github_pr_link)
        field = GithubLinkback.field_for(github_pr_link)
        expect(post.custom_fields[field]).to be_present

        expect(links[3].url).to eq(github_pr_link_wildcard)
        field = GithubLinkback.field_for(github_pr_link_wildcard)
        expect(post.custom_fields[field]).to be_present
      end

      it "should create linkback for <= SiteSetting.github_linkback_maximum_links urls" do
        SiteSetting.github_linkback_maximum_links = 2
        post = Fabricate(:post, raw: "#{github_pr_link} #{github_issue_link}")
        links = GithubLinkback.new(post).create
        expect(links.size).to eq(2)
      end

      it "should skip linkback for > SiteSetting.github_linkback_maximum_links urls" do
        SiteSetting.github_linkback_maximum_links = 1
        post = Fabricate(:post, raw: "#{github_pr_link} #{github_issue_link}")
        links = GithubLinkback.new(post).create
        expect(links.size).to eq(0)
      end

      it "should create linkback for <= SiteSetting.github_linkback_maximum_links unique urls" do
        SiteSetting.github_linkback_maximum_links = 1
        post = Fabricate(:post, raw: "#{github_pr_link} #{github_pr_link} #{github_pr_link}")
        links = GithubLinkback.new(post).create
        expect(links.size).to eq(1)
      end
    end
  end
end
