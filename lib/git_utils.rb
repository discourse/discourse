# frozen_string_literal: true

require_relative "version"

module GitUtils
  def git_version
    @git_version ||=
      begin
        git_cmd = "git rev-parse HEAD"
        self.try_git(git_cmd, Discourse::VERSION::STRING)
      end
  end

  def git_branch
    @git_branch ||=
      self.try_git("git branch --show-current", nil) ||
        self.try_git("git config user.discourse-version", "unknown")
  end

  def full_version
    @full_version ||=
      begin
        git_cmd = 'git describe --dirty --match "v[0-9]*" 2> /dev/null'
        self.try_git(git_cmd, "unknown")
      end
  end

  def last_commit_date
    @last_commit_date ||=
      begin
        git_cmd = 'git log -1 --format="%ct"'
        seconds = self.try_git(git_cmd, nil)
        seconds.nil? ? nil : DateTime.strptime(seconds, "%s")
      end
  end

  def try_git(git_cmd, default_value)
    begin
      `#{git_cmd}`.strip
    rescue StandardError
      default_value
    end || default_value
  end
end
