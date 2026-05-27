# frozen_string_literal: true

require "json"
require "open3"
require "optparse"
require "tempfile"

module UpcomingChanges
  class StatusReport
    SETTINGS_PATH = "config/site_settings.yml"
    PLUGIN_SETTINGS_PATH_PATTERN = "plugins/*/config/settings.yml"
    PROMOTIONS = { "experimental" => "alpha", "alpha" => "beta", "beta" => "stable" }.freeze
    TERMINAL_STATUSES = %w[conceptual stable permanent never].freeze
    STATUS_PATTERN = /\A(\s*)status:\s*(["']?)([^"'\s#]+)(["']?)([^\n]*)(\n?)\z/

    Commit =
      Struct.new(:sha, :date, :author_name, :author_email, :subject, keyword_init: true) do
        def to_h
          {
            "sha" => sha,
            "date" => date,
            "author_name" => author_name,
            "author_email" => author_email,
            "subject" => subject,
          }
        end
      end

    class Git
      def initialize(repo_path:)
        @repo_path = repo_path
      end

      def commits_for(path)
        output =
          capture("log", "--format=%H%x00%aI%x00%an%x00%ae%x00%s", "--", path, allow_failure: true)

        output.lines.filter_map do |line|
          sha, date, author_name, author_email, subject = line.chomp.split("\0", 5)
          next if sha.blank?

          Commit.new(sha:, date:, author_name:, author_email:, subject:)
        end
      end

      def show_file(commit_sha, path)
        capture("show", "#{commit_sha}:#{path}", allow_failure: true)
      end

      private

      def capture(*args, allow_failure: false)
        stdout, stderr, status = Open3.capture3("git", "-C", @repo_path, *args)
        return stdout if status.success? || allow_failure

        raise "git #{args.join(" ")} failed: #{stderr}"
      end
    end

    class MetadataLoader
      def self.from_current_site_setting(settings_path:)
        source_metadata = from_file(settings_path, strict: true)
        site_setting_metadata = SiteSetting.upcoming_change_metadata.slice(*source_metadata.keys)
        site_setting_metadata.presence || source_metadata
      end

      def self.from_content(content)
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

    class SourceStatusUpdater
      def initialize(settings_file:)
        @settings_file = settings_file
      end

      def update!(change_name:, next_status:)
        lines = File.readlines(@settings_file)
        status_line = status_line_for(change_name)
        raise "Could not locate status line for upcoming change: #{change_name}" if status_line.nil?

        lines[status_line] = lines[status_line].sub(STATUS_PATTERN) do
          prefix = "#{Regexp.last_match(1)}status: "
          quote = Regexp.last_match(2).to_s
          suffix = Regexp.last_match(5).to_s
          newline = Regexp.last_match(6).to_s
          closing_quote = quote.empty? ? "" : quote

          "#{prefix}#{quote}#{next_status}#{closing_quote}#{suffix}#{newline}"
        end

        File.write(@settings_file, lines.join)
      end

      private

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
      now: Time.current
    )
      @repo_path = repo_path
      @settings_path = settings_path
      @settings_paths = settings_paths
      @stale_after_days = stale_after_days.to_i
      @now = now
      @git = Git.new(repo_path:)
    end

    def report
      current_changes.map do |name, metadata|
        history = history_by_change.fetch(name, [])
        original_commit = history.first
        last_status_change = last_status_change_for(history)
        current_status = metadata[:status]&.to_s
        next_status = PROMOTIONS[current_status]
        eligible, reason = eligibility_for(current_status, last_status_change)

        {
          name: name.to_s,
          settings_path: metadata[:settings_path],
          current_status: current_status,
          next_status: next_status,
          eligible: eligible,
          eligibility_reason: reason,
          days_since_status_change: days_since(last_status_change),
          last_status_change_commit: last_status_change&.fetch(:commit)&.sha,
          last_status_change_date: last_status_change&.fetch(:commit)&.date,
          original_commit: original_commit&.fetch(:commit)&.sha,
          original_commit_date: original_commit&.fetch(:commit)&.date,
          original_author_name: original_commit&.fetch(:commit)&.author_name,
          original_author_email: original_commit&.fetch(:commit)&.author_email,
          original_pr_number: original_pr_number(original_commit),
        }
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

    def settings_file
      File.join(@repo_path, @settings_path)
    end

    def settings_paths
      @settings_paths ||=
        begin
          paths = [@settings_path]
          paths.concat(Dir.glob(File.join(@repo_path, PLUGIN_SETTINGS_PATH_PATTERN)).sort)
          paths
            .map { |path| File.expand_path(path, @repo_path) }
            .map { |path| Pathname.new(path).relative_path_from(Pathname.new(@repo_path)).to_s }
            .uniq
        end
    end

    def current_changes
      @current_changes ||=
        settings_paths
          .each_with_object({}) do |settings_path, result|
            metadata =
              MetadataLoader.from_current_site_setting(
                settings_path: File.join(@repo_path, settings_path),
              )

            metadata.each { |name, data| result[name] = data.merge(settings_path:) }
          end
          .sort
          .to_h
    end

    def history_by_change
      @history_by_change ||=
        begin
          result = Hash.new { |hash, key| hash[key] = [] }

          settings_paths.each do |settings_path|
            tracked_names =
              current_changes
                .select { |_, metadata| metadata[:settings_path] == settings_path }
                .keys

            @git
              .commits_for(settings_path)
              .reverse_each do |commit|
                statuses =
                  MetadataLoader
                    .from_content(@git.show_file(commit.sha, settings_path))
                    .transform_values { |metadata| metadata[:status]&.to_s }

                tracked_names.each do |name|
                  result[name] << { commit:, status: statuses[name] } if statuses.key?(name)
                end
              end
          end

          result
        end
    end

    def last_status_change_for(history)
      history
        .each_cons(2)
        .reduce(history.first) do |last_change, (previous, current)|
          previous[:status] == current[:status] ? last_change : current
        end
    end

    def eligibility_for(current_status, last_status_change)
      return false, "missing_status" if current_status.blank?
      return false, "terminal_status" if TERMINAL_STATUSES.include?(current_status)
      return false, "unknown_status" if !PROMOTIONS.key?(current_status)
      return false, "missing_git_history" if last_status_change.nil?

      return false, "status_changed_recently" if days_since(last_status_change) < @stale_after_days

      [true, "status_unchanged_for_#{@stale_after_days}_days"]
    end

    def days_since(history_entry)
      return nil if history_entry.nil?

      (@now - Time.iso8601(history_entry.fetch(:commit).date)).to_i / 1.day
    end

    def original_pr_number(history_entry)
      subject = history_entry&.fetch(:commit)&.subject
      subject&.match(/\(#(\d+)\)\z/)&.[](1) || subject&.match(/#(\d+)/)&.[](1)
    end

    class CLI
      def self.run(args)
        options = {
          repo_path: Rails.root.to_s,
          settings_paths: nil,
          stale_after_days: 14,
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
            opts.on("--pretty", "Pretty-print JSON output") { options[:pretty] = true }
          end

        parser.parse!(args)

        status_report =
          StatusReport.new(
            repo_path: options[:repo_path],
            settings_paths: options[:settings_paths],
            stale_after_days: options[:stale_after_days],
          )
        output = options[:apply] ? status_report.apply(options[:apply]) : status_report.report
        puts(options[:pretty] ? JSON.pretty_generate(output) : JSON.generate(output))
      end
    end
  end
end
