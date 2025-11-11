# frozen_string_literal: true

require_dependency "pretty_text"
require "digest/sha1"

class GithubLinkback
  class Link
    attr_reader :url, :project, :type
    attr_accessor :sha, :pr_number, :issue_number

    def initialize(url, project, type)
      @url = url
      @project = project
      @type = type
    end
  end

  def initialize(post)
    @post = post
  end

  def should_enqueue?
    !!(
      SiteSetting.github_linkback_enabled? && SiteSetting.enable_discourse_github_plugin? &&
        @post.present? && @post.post_type == Post.types[:regular] && @post.raw =~ /github\.com/ &&
        Guardian.new.can_see?(@post) && @post.topic.visible?
    )
  end

  def enqueue
    Jobs.enqueue(:create_github_linkback, post_id: @post.id) if should_enqueue?
  end

  def github_links
    projects = SiteSetting.github_linkback_projects.split("|")

    return [] if projects.blank?

    result = {}
    PrettyText
      .extract_links(@post.cooked)
      .map(&:url)
      .each do |l|
        if l =~ %r{https?://github\.com/([^/]+)/([^/]+)/commit/([0-9a-f]+)}
          url, org, repo, sha = Regexp.last_match.to_a
          project = "#{org}/#{repo}"

          next if result[url]
          next if @post.custom_fields[GithubLinkback.field_for(url)].present?
          next unless is_allowed_project_link?(projects, project)

          link = Link.new(url, project, :commit)
          link.sha = sha
          result[url] = link
        elsif l =~ %r{https?://github.com/([^/]+)/([^/]+)/pull/(\d+)}
          url, org, repo, pr_number = Regexp.last_match.to_a
          project = "#{org}/#{repo}"

          next if result[url]
          next if @post.custom_fields[GithubLinkback.field_for(url)].present?
          next unless is_allowed_project_link?(projects, project)

          link = Link.new(url, project, :pr)
          link.pr_number = pr_number.to_i
          result[url] = link
        elsif l =~ %r{https?://github.com/([^/]+)/([^/]+)/issues/(\d+)}
          url, org, repo, issue_number = Regexp.last_match.to_a
          project = "#{org}/#{repo}"

          next if result[url]
          next if @post.custom_fields[GithubLinkback.field_for(url)].present?
          next unless is_allowed_project_link?(projects, project)

          link = Link.new(url, project, :issue)
          link.issue_number = issue_number.to_i
          result[url] = link
        end
      end
    result.values
  end

  def is_allowed_project_link?(projects, project)
    return true if projects.include?(project)

    check_user = project.split("/")[0]
    projects.any? do |allowed_project|
      allowed_user, allowed_all_projects = allowed_project.split("/")
      (allowed_user == check_user) && (allowed_all_projects == "*")
    end
  end

  def create
    return [] if SiteSetting.github_linkback_access_token.blank?

    links = []

    DistributedMutex.synchronize("github_linkback_#{@post.id}") do
      links = github_links
      return [] if links.length() > SiteSetting.github_linkback_maximum_links

      links.each do |link|
        case link.type
        when :commit
          post_commit(link)
        when :pr
          post_pr_or_issue(link, :pr)
        when :issue
          post_pr_or_issue(link, :issue)
        else
          next
        end

        # Don't post the same link twice
        @post.custom_fields[GithubLinkback.field_for(link.url)] = "true"
      end
      @post.save_custom_fields
    end

    links
  end

  def self.field_for(url)
    "github-linkback:#{Digest::SHA1.hexdigest(url)[0..15]}"
  end

  private

  def post_pr_or_issue(link, type)
    pr_or_issue_number = link.pr_number || link.issue_number
    github_url =
      "https://api.github.com/repos/#{link.project}/issues/#{pr_or_issue_number}/comments"
    comment =
      I18n.t(
        type == :pr ? "github_linkback.pr_template" : "github_linkback.issue_template",
        title: SiteSetting.title,
        post_url: "#{Discourse.base_url}#{@post.url}",
      )

    Excon.post(github_url, body: { body: comment }.to_json, headers: headers)
  end

  def post_commit(link)
    github_url = "https://api.github.com/repos/#{link.project}/commits/#{link.sha}/comments"

    comment =
      I18n.t(
        "github_linkback.commit_template",
        title: SiteSetting.title,
        post_url: "#{Discourse.base_url}#{@post.url}",
      )

    Excon.post(github_url, body: { body: comment }.to_json, headers: headers)
  end

  def headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "token #{SiteSetting.github_linkback_access_token}",
      "User-Agent" => "Discourse-Github-Linkback",
    }
  end
end
