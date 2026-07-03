# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "pathname"
require "psych"
require "tempfile"

module UpcomingChanges
  class StatusReport
    SETTINGS_PATH = "config/site_settings.yml"
    PLUGIN_SETTINGS_PATH_PATTERN = "plugins/*/config/settings.yml"
    STATUS_PATTERN = /\A(\s*)status:\s*(["']?)([^"'\s#]+)\2([^\n]*)(\n?)\z/
    # Bounds how far back git history is scanned. Upcoming changes are short-lived, so a
    # year is plenty and avoids re-parsing thousands of historical settings revisions.
    DEFAULT_HISTORY_SINCE = "1 year ago"

    Commit = Struct.new(:sha, :date, :author_name, :author_email, :subject, keyword_init: true)
    HistoryEntry = Struct.new(:commit, :status, keyword_init: true)

    class Git
      def initialize(repo_path:, since: nil)
        @repo_path = repo_path
        @since = since
      end

      # Only commits within @since are returned. For a change whose status last moved
      # before the window, the oldest in-window commit becomes the apparent first/last
      # status change. Eligibility is unaffected (its age is still well past the staleness
      # threshold); only the reported original author/PR may point at the window boundary.
      def commits_for(path)
        args = %w[log --format=%H%x00%aI%x00%an%x00%ae%x00%s]
        args << "--since=#{@since}" if @since.present?
        args += ["--", path]
        output = capture(*args)

        output.lines.filter_map do |line|
          sha, date, author_name, author_email, subject = line.chomp.split("\0", 5)
          next if sha.blank?

          Commit.new(sha:, date:, author_name:, author_email:, subject:)
        end
      end

      def show_file(commit_sha, path)
        capture("show", "#{commit_sha}:#{path}")
      end

      private

      def capture(*args)
        stdout, stderr, status = Open3.capture3("git", "-C", @repo_path, *args)
        return stdout if status.success?

        raise "git #{args.join(" ")} failed: #{stderr}"
      end
    end

    class MetadataLoader
      def self.from_content(content)
        return {} if content.blank?

        Tempfile.create(%w[upcoming-change-settings .yml]) do |file|
          file.write(content)
          file.close

          from_file(file.path, strict: false)
        end
      end

      def self.from_file(path, strict:)
        site_settings = Class.new { extend SiteSettingExtension }
        site_settings.load_settings(path)
        site_settings.upcoming_change_metadata
      rescue => error
        raise if strict

        Rails.logger.warn("Failed to parse historical site settings from #{path}: #{error.message}")
        {}
      end
    end

    class SourceIndex
      def initialize(repo_path:, settings_path:, settings_paths:)
        @repo_path = repo_path
        @settings_path = settings_path
        @configured_settings_paths = settings_paths
      end

      def changes
        @changes ||=
          settings_paths
            .each_with_object({}) do |settings_path, result|
              MetadataLoader
                .from_file(File.join(@repo_path, settings_path), strict: true)
                .each { |name, metadata| result[name.to_sym] = metadata.merge(settings_path:) }
            end
            .sort
            .to_h
      end

      def change_names
        changes.keys
      end

      def explicit_paths?
        @configured_settings_paths.present?
      end

      def metadata_for(change_name)
        changes[change_name.to_sym]
      end

      def settings_path_for(change_name)
        metadata_for(change_name)&.fetch(:settings_path) || plugin_settings_path_for(change_name) ||
          @settings_path
      end

      private

      def settings_paths
        @settings_paths ||=
          normalize_paths(@configured_settings_paths.presence || default_settings_paths)
      end

      def default_settings_paths
        [@settings_path, *Dir.glob(File.join(@repo_path, PLUGIN_SETTINGS_PATH_PATTERN)).sort]
      end

      def normalize_paths(paths)
        paths
          .map { |path| File.expand_path(path, @repo_path) }
          .map { |path| Pathname.new(path).relative_path_from(Pathname.new(@repo_path)).to_s }
          .uniq
      end

      def plugin_settings_path_for(change_name)
        plugin_name = SiteSetting.plugins[change_name.to_sym]
        return if plugin_name.blank?

        "plugins/#{plugin_name}/config/settings.yml"
      end
    end

    class CurrentChanges
      def initialize(repo_path:, source_index:)
        @repo_path = repo_path
        @source_index = source_index
      end

      def call
        current_change_names
          .each_with_object({}) do |change_name, result|
            metadata = source_metadata_for(change_name).merge(core_metadata_for(change_name))
            result[change_name] = metadata.merge(settings_path: settings_path_for(change_name))
          end
          .sort
          .to_h
      end

      private

      def current_change_names
        return @source_index.change_names.sort if source_only?

        (@source_index.change_names + SiteSetting.upcoming_change_site_settings)
          .map(&:to_sym)
          .uniq
          .sort
      end

      def source_only?
        @source_index.explicit_paths? ||
          File.expand_path(@repo_path) != File.expand_path(Rails.root.to_s)
      end

      def source_metadata_for(change_name)
        @source_index.metadata_for(change_name) || {}
      end

      def core_metadata_for(change_name)
        return {} if source_only?

        SiteSetting.upcoming_change_metadata[change_name.to_sym] || {}
      end

      def settings_path_for(change_name)
        source_metadata_for(change_name)[:settings_path] ||
          @source_index.settings_path_for(change_name)
      end
    end

    class GitHistory
      def initialize(git:)
        @git = git
      end

      def by_change(changes)
        changes
          .group_by { |_, metadata| metadata[:settings_path] }
          .each_with_object(
            Hash.new { |hash, key| hash[key] = [] },
          ) do |(settings_path, entries), result|
            add_history_for_settings_file(result, settings_path, entries.map(&:first))
          end
      end

      private

      def add_history_for_settings_file(result, settings_path, change_names)
        @git
          .commits_for(settings_path)
          .reverse_each do |commit|
            statuses = statuses_at(commit, settings_path)

            change_names.each do |change_name|
              next if !statuses.key?(change_name)

              result[change_name] << HistoryEntry.new(commit:, status: statuses[change_name])
            end
          end
      end

      def statuses_at(commit, settings_path)
        MetadataLoader
          .from_content(@git.show_file(commit.sha, settings_path))
          .transform_values { |metadata| metadata[:status]&.to_s }
      end
    end

    class PullRequestPlan
      BRANCH_PREFIX = "dev/upcoming-change-status-bump"
      LABEL = "upcoming-change"

      def self.add_to(record, stale_after_days:)
        return record if !record[:eligible]

        record.merge(
          branch: "#{BRANCH_PREFIX}/#{record[:name]}",
          title: "FEATURE: Bump #{record[:name]} upcoming change to #{record[:next_status]}",
          pr_label: LABEL,
          pr_body: body_for(record, stale_after_days:),
        )
      end

      def self.body_for(record, stale_after_days:)
        <<~MD.chomp
          <!-- upcoming-change-status-pr:#{record[:name]} -->

          This automated PR moves `#{record[:name]}` from `#{record[:current_status]}` to `#{record[:next_status]}` after #{stale_after_days}+ days without a status change.

          - Last status change commit: #{commit_link(record[:last_status_change_commit])}
          - Last status change date: `#{record[:last_status_change_date]}`
          - Settings file: `#{record[:settings_path]}`
          - Original author: #{original_author(record)}
          - Original PR: #{original_pr(record)}
        MD
      end

      def self.commit_link(commit_sha)
        return "N/A" if commit_sha.blank?

        "[`#{commit_sha}`](https://github.com/discourse/discourse/commit/#{commit_sha})"
      end

      def self.original_author(record)
        return "N/A" if record[:original_author_name].blank?

        "#{record[:original_author_name]} (<#{record[:original_author_email]}>)"
      end

      def self.original_pr(record)
        return "N/A" if record[:original_pr_number].blank?

        "##{record[:original_pr_number]}"
      end
    end

    class SourceStatusUpdater
      def initialize(settings_file:)
        @settings_file = settings_file
      end

      def update!(change_name:, next_status:)
        lines = File.readlines(@settings_file)
        status_line = status_line_for(change_name)
        raise "Could not locate status line for upcoming change: #{change_name}" if status_line.nil?

        original_line = lines.fetch(status_line)
        lines[status_line] = updated_status_line(original_line, next_status)
        if original_line == lines[status_line]
          raise "Status line for upcoming change #{change_name} did not change"
        end

        File.write(@settings_file, lines.join)
      end

      private

      def updated_status_line(line, next_status)
        match = STATUS_PATTERN.match(line)
        raise "Could not parse status line: #{line.strip}" if match.nil?

        indentation, quote, _old_status, suffix, newline = match.captures
        "#{indentation}status: #{quote}#{next_status}#{quote}#{suffix}#{newline}"
      end

      def status_line_for(change_name)
        root = Psych.parse_file(@settings_file).root
        return if !root.is_a?(Psych::Nodes::Mapping)

        each_pair(root) do |_category_key, category_value|
          next if !category_value.is_a?(Psych::Nodes::Mapping)

          each_pair(category_value) do |setting_key, setting_value|
            next if setting_key.value != change_name
            next if !setting_value.is_a?(Psych::Nodes::Mapping)

            return status_line_in(setting_value)
          end
        end

        nil
      end

      def status_line_in(setting_node)
        each_pair(setting_node) do |setting_key, setting_value|
          next if setting_key.value != "upcoming_change"
          next if !setting_value.is_a?(Psych::Nodes::Mapping)

          each_pair(setting_value) do |metadata_key, metadata_value|
            return metadata_value.start_line if metadata_key.value == "status"
          end
        end

        nil
      end

      def each_pair(mapping)
        mapping.children.each_slice(2) { |key, value| yield key, value }
      end
    end

    def initialize(
      repo_path: Rails.root.to_s,
      settings_path: SETTINGS_PATH,
      settings_paths: nil,
      stale_after_days: 14,
      history_since: DEFAULT_HISTORY_SINCE,
      now: Time.current
    )
      @repo_path = repo_path
      @settings_path = settings_path
      @stale_after_days = stale_after_days.to_i
      @now = now
      @source_index = SourceIndex.new(repo_path:, settings_path:, settings_paths:)
      @git = Git.new(repo_path:, since: history_since)
    end

    def report
      current_changes.map do |name, metadata|
        build_record(name, metadata, history_by_change.fetch(name, []))
      end
    end

    def apply(change_name)
      record = report.find { |change| change[:name] == change_name.to_s }
      raise "Unknown upcoming change: #{change_name}" if record.nil?
      raise "Upcoming change is not eligible: #{record[:eligibility_reason]}" if !record[:eligible]

      SourceStatusUpdater.new(settings_file: File.join(@repo_path, record[:settings_path])).update!(
        change_name: change_name.to_s,
        next_status: record[:next_status],
      )

      record.merge(applied: true)
    end

    private

    def build_record(name, metadata, history)
      original_commit = history.first
      last_status_change = last_status_change_for(history)
      current_status = metadata[:status]&.to_s
      next_status = UpcomingChanges.next_status(current_status)&.to_s
      eligible, reason = eligibility_for(current_status:, next_status:, last_status_change:)

      PullRequestPlan.add_to(
        {
          name: name.to_s,
          settings_path: metadata[:settings_path],
          current_status:,
          next_status:,
          eligible:,
          eligibility_reason: reason,
          days_since_status_change: days_since(last_status_change),
          last_status_change_commit: last_status_change&.commit&.sha,
          last_status_change_date: last_status_change&.commit&.date,
          original_commit: original_commit&.commit&.sha,
          original_commit_date: original_commit&.commit&.date,
          original_author_name: original_commit&.commit&.author_name,
          original_author_email: original_commit&.commit&.author_email,
          original_pr_number: original_pr_number(original_commit),
        },
        stale_after_days: @stale_after_days,
      )
    end

    def current_changes
      @current_changes ||=
        CurrentChanges.new(repo_path: @repo_path, source_index: @source_index).call
    end

    def changes_needing_history
      current_changes.select do |_, metadata|
        UpcomingChanges.next_status(metadata[:status]).present?
      end
    end

    def history_by_change
      @history_by_change ||= GitHistory.new(git: @git).by_change(changes_needing_history)
    end

    def last_status_change_for(history)
      history
        .each_cons(2)
        .reduce(history.first) do |last_change, (previous, current)|
          previous.status == current.status ? last_change : current
        end
    end

    def eligibility_for(current_status:, next_status:, last_status_change:)
      return false, "missing_status" if current_status.blank?
      return false, "unknown_status" if UpcomingChanges.statuses[current_status.to_sym].nil?
      return false, "terminal_status" if next_status.blank?
      return false, "missing_git_history" if last_status_change.nil?

      return false, "status_changed_recently" if days_since(last_status_change) < @stale_after_days

      [true, "status_unchanged_for_#{@stale_after_days}_days"]
    end

    def days_since(history_entry)
      return nil if history_entry.nil?

      (@now - Time.iso8601(history_entry.commit.date)).to_i / 1.day
    end

    def original_pr_number(history_entry)
      subject = history_entry&.commit&.subject
      subject&.match(/\(#(\d+)\)\z/)&.[](1) || subject&.match(/#(\d+)/)&.[](1)
    end

    class CLI
      def self.run(args)
        options = {
          repo_path: Rails.root.to_s,
          settings_paths: nil,
          stale_after_days: 14,
          history_since: DEFAULT_HISTORY_SINCE,
          pretty: false,
        }

        parser =
          OptionParser.new do |opts|
            opts.banner =
              "Usage: bin/rails runner script/upcoming_changes_status_report -- [options]"

            opts.on(
              "--apply NAME",
              "Apply the next status for one eligible upcoming change",
            ) { |name| options[:apply] = name }

            opts.on("--repo PATH", "Git repository path") { |path| options[:repo_path] = path }
            opts.on(
              "--settings-path PATH",
              "Only inspect one settings YAML path; defaults to core and plugin settings",
            ) { |path| options[:settings_paths] = [path] }
            opts.on("--stale-after-days DAYS", Integer, "Minimum unchanged age") do |days|
              options[:stale_after_days] = days
            end
            opts.on(
              "--history-since VALUE",
              "How far back to scan git history (any git --since value); defaults to '#{DEFAULT_HISTORY_SINCE}'",
            ) { |value| options[:history_since] = value }
            opts.on("--pretty", "Pretty-print JSON output") { options[:pretty] = true }
          end

        parser.parse!(args)

        status_report =
          StatusReport.new(
            repo_path: options[:repo_path],
            settings_paths: options[:settings_paths],
            stale_after_days: options[:stale_after_days],
            history_since: options[:history_since],
          )
        output = options[:apply] ? status_report.apply(options[:apply]) : status_report.report
        puts(options[:pretty] ? JSON.pretty_generate(output) : JSON.generate(output))
      end
    end
  end
end
