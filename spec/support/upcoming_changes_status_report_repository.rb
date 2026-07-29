# frozen_string_literal: true

class UpcomingChangesStatusReportRepository
  def initialize(path:)
    @path = path
  end

  def git(*arguments, env: {})
    stdout, stderr, status = Open3.capture3(env, "git", "-C", @path, *arguments)
    raise "git #{arguments.join(" ")} failed: #{stderr}" if !status.success?
    stdout
  end

  def commit(message:, date:, author_name:, author_email:)
    git("add", ".")
    git(
      "commit",
      "-m",
      message,
      env: {
        "GIT_AUTHOR_DATE" => date,
        "GIT_COMMITTER_DATE" => date,
        "GIT_AUTHOR_NAME" => author_name,
        "GIT_AUTHOR_EMAIL" => author_email,
        "GIT_COMMITTER_NAME" => "Discourse CI",
        "GIT_COMMITTER_EMAIL" => "ci@ci.invalid",
      },
    )
    git("rev-parse", "HEAD").strip
  end

  def write_settings(statuses:)
    write_settings_file(
      path: File.join(@path, "config/site_settings.yml"),
      root: "experimental",
      statuses:,
    )
  end

  def write_plugin_settings(statuses:)
    write_settings_file(
      path: File.join(@path, "plugins/chat/config/settings.yml"),
      root: "chat",
      statuses:,
    )
  end

  private

  def write_settings_file(path:, root:, statuses:)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{root}:\n")
    File.open(path, "a") do |file|
      statuses.each do |name, status|
        file.write("  #{name}:\n")
        file.write("    default: false\n")
        file.write("    client: true\n")
        file.write("    hidden: true\n")
        file.write("    upcoming_change:\n")
        file.write("      status: #{status}\n")
        file.write("      impact: \"feature,all_members\"\n")
        file.write("      learn_more_url: \"https://meta.discourse.org/t/-/123\"\n")
      end
    end
  end
end
