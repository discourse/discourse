# frozen_string_literal: true

class GitUtils
  def self.git_version
    self.try_git("git rev-parse HEAD", "unknown")
  end

  def self.git_branch
    self.try_git("git branch --show-current", nil) ||
      self.try_git("git config user.discourse-version", "unknown")
  end

  def self.full_version
    self.try_git('git describe --dirty --match "v[0-9]*" 2> /dev/null', "unknown")
  end

  def self.last_commit_date
    git_cmd = 'git log -1 --format="%ct"'
    seconds = self.try_git(git_cmd, nil)
    seconds.nil? ? nil : DateTime.strptime(seconds, "%s")
  end

  def self.try_git(git_cmd, default_value)
    value =
      begin
        `#{git_cmd}`.strip
      rescue StandardError
        default_value
      end

    (!value.empty? ? value : nil) || default_value
  end
end
