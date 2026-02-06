# frozen_string_literal: true

class GitUtils
  def self.git_version
    filesystem_overrides["git_version"] || self.try_git("git rev-parse HEAD", "unknown")
  end

  def self.git_branch
    filesystem_overrides["git_branch"] || self.try_git("git branch --show-current", nil) ||
      self.try_git("git config user.discourse-version", "unknown")
  end

  def self.full_version
    filesystem_overrides["full_version"] ||
      self.try_git('git describe --dirty --match "v[0-9]*" 2> /dev/null', "unknown")
  end

  def self.has_commit?(hash)
    return false if !hash.match?(/\A[a-f0-9]{40}\Z/)

    self.try_git("git merge-base --is-ancestor #{hash} HEAD 2> /dev/null; echo $?", "1") == "0"
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

  # The `config/git-utils-override.json` file can be used by hosting providers
  # to override the git information that Discourse reports in the UI.
  private_class_method def self.filesystem_overrides
    @filesystem_overrides ||=
      begin
        JSON.parse(File.read("#{rails_root}/config/git-utils-overrides.json"))
      rescue Errno::ENOENT
        {}
      end
  end

  private_class_method def self.rails_root
    # Can't use `Rails.root` here because GitUtils is `require`'d before Rails is initialized'
    Pathname.new(File.expand_path("..", __dir__))
  end
end
