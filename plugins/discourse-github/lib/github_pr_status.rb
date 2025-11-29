# frozen_string_literal: true

class GithubPrStatus
  extend Onebox::Mixins::GithubAuthHeader

  def self.fetch(owner, repo, number)
    pr_data = fetch_json("https://api.github.com/repos/#{owner}/#{repo}/pulls/#{number}", owner)

    return "merged" if pr_data["merged"]
    return "closed" if pr_data["state"] == "closed"
    return "draft" if pr_data["draft"]

    reviews_data =
      fetch_json("https://api.github.com/repos/#{owner}/#{repo}/pulls/#{number}/reviews", owner)
    return "approved" if approved?(reviews_data)

    "open"
  rescue StandardError => e
    Rails.logger.error("GitHub PR status error: #{e.message}")
    nil
  end

  private

  def self.fetch_json(url, owner)
    uri = URI.parse(url)
    response = uri.open({ read_timeout: 10 }.merge(github_auth_header(owner)))
    ::MultiJson.load(response.read)
  rescue OpenURI::HTTPError => e
    if e.io.status[0] == "403" && e.io.meta["x-ratelimit-remaining"] == "0"
      reset_time = e.io.meta["x-ratelimit-reset"]&.to_i
      reset_at = reset_time ? Time.at(reset_time).utc : "unknown"
      Rails.logger.warn("GitHub API rate limit exceeded for #{url}. Resets at: #{reset_at}.")
    end
    raise
  end

  def self.approved?(reviews)
    return false if reviews.blank?

    latest_by_user = {}
    reviews.each do |review|
      next unless user_id = review.dig("user", "id")
      next if review["state"] == "PENDING" || review["state"] == "COMMENTED"

      existing = latest_by_user[user_id]
      if existing.nil? || review["submitted_at"] > existing["submitted_at"]
        latest_by_user[user_id] = review
      end
    end

    return false if latest_by_user.empty?

    states = latest_by_user.values.map { |r| r["state"] }
    states.all? { |s| s == "APPROVED" || s == "DISMISSED" } && states.include?("APPROVED")
  end
end
