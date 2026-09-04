# frozen_string_literal: true

require "open3"

class GitUtils
  # Shelling out to git can block indefinitely (a wedged git process, a stalled
  # filesystem under `.git`, fork pressure on a loaded box). Callers get the
  # fallback value instead of hanging.
  COMMAND_TIMEOUT_SECONDS = 5

  class << self
    def git_version
      filesystem_overrides["git_version"] || try_git("git rev-parse HEAD", "unknown")
    end

    def git_branch
      filesystem_overrides["git_branch"] || try_git("git branch --show-current", nil) ||
        try_git("git config user.discourse-version", "unknown")
    end

    def full_version
      filesystem_overrides["full_version"] ||
        try_git('git describe --dirty --match "v[0-9]*" 2> /dev/null', "unknown")
    end

    def has_commit?(hash)
      return false if !hash.match?(/\A[a-f0-9]{40}\Z/)

      @has_commit ||= {}
      return @has_commit[hash] if @has_commit.key?(hash)

      # `echo $?` means the output is git's own exit status: 0 for an ancestor, 1 for
      # not, 128 when the commit isn't in the repo at all. `nil` means git never ran,
      # which is not an answer, so it isn't memoized.
      result =
        try_git(
          "git merge-base --is-ancestor #{hash} HEAD 2> /dev/null; echo $?",
          nil,
          # We are deployed from a partial clone, where a commit missing from the
          # local graph is otherwise lazily fetched from the remote: a blocking
          # network call, with no timeout of its own, to answer what has to stay a
          # local question.
          env: {
            "GIT_NO_LAZY_FETCH" => "1",
          },
        )
      return false if result.nil?

      @has_commit[hash] = result == "0"
    end

    def last_commit_date
      git_cmd = "git rev-list -1 --no-commit-header --format=%ct HEAD"
      seconds = try_git(git_cmd, nil)
      seconds.nil? ? nil : DateTime.strptime(seconds, "%s")
    end

    def try_git(git_cmd, default_value, timeout: COMMAND_TIMEOUT_SECONDS, env: {})
      value =
        begin
          capture_stdout(git_cmd, timeout, env)&.strip
        rescue StandardError
          nil
        end

      # Can't use `presence` here, ActiveSupport may not be loaded yet
      value.nil? || value.empty? ? default_value : value
    end

    # The `config/git-utils-override.json` file can be used by hosting providers
    # to override the git information that Discourse reports in the UI.

    private

    # Only stdout is returned, matching the behaviour of a backtick call. stderr is
    # read in its own thread so a chatty command can't fill the pipe and deadlock,
    # then passed through to ours, where it used to go directly.
    def capture_stdout(git_cmd, timeout, env)
      Open3.popen3(env, git_cmd, pgroup: true) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        out_reader = Thread.new { stdout.read }
        err_reader = Thread.new { stderr.read }

        if wait_thr.join(timeout).nil?
          kill_process_group(wait_thr.pid)
          [out_reader, err_reader].each(&:kill)
          STDERR.puts("GitUtils: `#{git_cmd}` timed out after #{timeout}s")
          return nil
        end

        errors = err_reader.value
        STDERR.write(errors) if !errors.nil? && !errors.empty?
        out_reader.value
      end
    end

    def kill_process_group(pid)
      Process.kill("KILL", -pid)
    rescue Errno::ESRCH, Errno::EPERM
      # already gone
    end

    def filesystem_overrides
      @filesystem_overrides ||=
        begin
          JSON.parse(File.read("#{rails_root}/config/git-utils-overrides.json"))
        rescue Errno::ENOENT
          {}
        end
    end

    private

    def rails_root
      # Can't use `Rails.root` here because GitUtils is `require`'d before Rails is initialized
      Pathname.new(File.expand_path("..", __dir__))
    end
  end
end
