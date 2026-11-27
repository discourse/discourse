# frozen_string_literal: true

require "csv"
require_relative "support"
require_relative "content_policy"

module BulkImport::DiscourseMerge
  class CustomerReport
    attr_reader :account_csv_path

    REQUIRED_CHECKS = %w[
      complete_topic_map
      excluded_topics_unmapped
      complete_post_map
      complete_upload_map
      existing_destination_records_preserved
      source_records_unchanged
    ].freeze

    def initialize(directory)
      @directory = directory
    end

    def write
      state = JSON.parse(@directory.join("active-run.json").read)
      unless state.fetch("status") == "verified"
        raise Error, "A customer report requires a successfully verified apply"
      end
      run = @directory.join("runs", File.basename(state.fetch("run_dir")))
      frozen_plan = run.join("plan.json").binread
      @plan = Plan.new(JSON.parse(frozen_plan))
      checks = JSON.parse(run.join("verification.json").read)
      plan_hash = Digest::SHA256.hexdigest(frozen_plan)
      unless state.fetch("plan_sha256") == plan_hash
        raise Error, "Frozen run plan changed; restore the original evidence"
      end
      unless checks["status"] == "passed" && REQUIRED_CHECKS.all? { |key| checks[key] == true } &&
               checks.except("status", "evidence_sha256", "report_summary").values.all?(true)
        raise Error, "A customer report requires a final ledger and passing verification"
      end
      if @plan.data.dig("upload_policy", "mode") == "preuploaded" && !checks["prepared_media"]
        raise Error, "A customer report requires verified prepared uploads"
      end
      if @plan.data.fetch("format_version") >= 3 &&
           !(
             checks["reviewed_content"] == true &&
               checks["reviewed_destination_content_settings"] == true &&
               checks.dig("report_summary", "content") ==
                 ContentPolicy.summary(@plan.data.fetch("content"))
           )
        raise Error, "A customer report requires verified content decisions"
      end
      if @plan.data["merge_member_activity"] &&
           !(
             checks["matched_member_summaries"] == true &&
               checks["matched_member_visit_dates"] == true
           )
        raise Error, "A customer report requires verified matched member summaries"
      end
      frozen_ledger = run.join("ledger.json").binread
      bound = checks.key?("evidence_sha256")
      if bound || @plan.data.key?("source_categories") || checks.key?("report_summary")
        hashes = {
          "plan.json" => plan_hash,
          "ledger.json" => Digest::SHA256.hexdigest(frozen_ledger),
        }
        unless checks["evidence_sha256"] == hashes
          raise Error, "The frozen plan and ledger must match the passing verification evidence"
        end
      end
      ledger = JSON.parse(frozen_ledger)
      if ledger.key?("account_outcomes") && checks["account_outcomes"] != true
        raise Error, "A customer report requires verified account outcomes"
      end
      summary = checks.fetch("report_summary") { legacy_summary(ledger, checks, bound) }
      path = @directory.join("customer-report.md")
      lines = render(summary)
      csv = account_outcomes(ledger) if bound
      if csv
        @account_csv_path = @directory.join("account-outcomes.csv")
        Artifacts.write(@account_csv_path, csv)
        lines << "" << "Account matches and username changes are in `account-outcomes.csv`."
      else
        lines << "" <<
          "Account CSV unavailable for this run because verified account evidence is incomplete."
      end
      Artifacts.write(path, lines.join("\n") + "\n")
      path
    rescue Errno::ENOENT, JSON::ParserError, KeyError, TypeError, ArgumentError
      raise Error,
            "A customer report requires a verified run with complete plan and ledger evidence"
    end

    private

    def account_outcomes(ledger)
      raise Error, "Incomplete account ledger" unless ledger.fetch("stage") == "complete"
      rows =
        if ledger.key?("account_outcomes")
          labels = {
            "email_match" => "Matched by email",
            "username_collision" => "Created after username collision",
          }
          ledger
            .fetch("account_outcomes")
            .values
            .map do |outcome|
              name, final = outcome.fetch_values("source_username", "final_username")
              [name, final, labels.fetch(outcome.fetch("reason")), name != final]
            end
        else
          legacy_account_rows(ledger)
        end
      return unless rows
      CSV.generate do |csv|
        csv << %w[source_username final_username account_outcome username_changed]
        rows
          .sort_by { |original, *| [original.downcase, original] }
          .each { |row| csv << row.map { |cell| Artifacts.csv_encode(cell) } }
      end
    end

    def legacy_account_rows(ledger)
      matches = @plan.data.dig("source_findings", "account_matches")
      decisions = @plan.data["matched_avatars"]
      return unless matches && decisions && ledger["users"] && ledger["username_changes"]

      pairs =
        matches.to_h { |row| [row.fetch("source_user_id").to_s, row.fetch("destination_user_id")] }
      changes = ledger.fetch("username_changes").dup
      if (sources = ledger["username_change_sources"])
        unless sources.keys.to_set == changes.keys.to_set
          raise Error, "Incomplete username change evidence"
        end
        changes.select! { |name, _| Integer(sources.fetch(name)).positive? }
      elsif changes.any? && ledger.fetch("users").keys.any? { |id| Integer(id) < -2 }
        # Older runs did not bind changed usernames to historical bot IDs.
        return
      end
      rows = []
      decisions.each do |decision|
        final = decision.fetch("username")
        target = decision.fetch("destination_user_id")
        decision
          .fetch("sources")
          .each do |source_id, original|
            recorded_name = changes.delete(original) || original
            unless pairs.delete(source_id) == target &&
                     ledger.fetch("users").fetch(source_id) == target && recorded_name == final
              raise Error, "Account outcome differs from verified mapping"
            end
            rows << [original, final, "Matched by email", original != final]
          end
      end
      raise Error, "Incomplete member matches" unless pairs.empty? && rows.size == matches.size
      changes.each do |original, final|
        rows << [original, final, "Created after username collision", true]
      end
      rows
    end

    def legacy_summary(ledger, checks, bound)
      topics = ledger.fetch("topics").transform_keys { |id| Integer(id) }
      unless ledger.fetch("stage") == "complete" && topics.keys.to_set == @plan.included_ids &&
               topics.values.uniq.size == topics.size &&
               topics.keys.all? { |id| checks["topic_#{id}_destination"] == true }
        raise Error, "A customer report requires a final ledger and passing verification"
      end
      if @plan.data.key?("source_categories")
        destinations = ledger.fetch("category_keys")
        unless checks["destination_login_required"] == true &&
                 destinations.keys.to_set == @plan.categories.keys.to_set &&
                 destinations.values.uniq.size == destinations.size &&
                 destinations.values.all? { |id|
                   %w[name parent read_access].all? do |field|
                     checks["category_#{id}_#{field}"] == true
                   end
                 }
          raise Error, "A customer report requires verified destination category paths and access"
        end
      end
      ReportSummary.new(@plan).build(
        posts: bound ? ledger.fetch("posts").size : nil,
        uploads: bound ? ledger.fetch("uploads").size : nil,
      )
    end

    def render(summary)
      [
        "# Customer merge report",
        "",
        "## Results",
        "",
        "- Discussions moved — #{summary.fetch("discussions")}",
        "- Private messages moved — #{summary.fetch("private_messages")}",
        (
          if summary.fetch("posts")
            "- Posts mapped — #{summary.fetch("posts")}"
          else
            "- Verified post total unavailable for this historical run."
          end
        ),
        "",
        "## Discussion routes",
        "",
        *routes(summary),
        "",
        "## Exclusions",
        "",
        *exclusions(summary),
        "",
        "## Media",
        "",
        (
          if summary.fetch("uploads")
            "- Upload records mapped — #{summary.fetch("uploads")}"
          else
            "- Verified upload total unavailable for this historical run."
          end
        ),
        (
          if @plan.data.dig("upload_policy", "preserve_destination_uploads")
            "- Destination media references were retained. Incoming files were verified against the reviewed target."
          elsif @plan.data.dig("upload_policy", "mode") == "preuploaded"
            "- Incoming and destination media were prepared for hosted storage before export."
          elsif @plan.data.fetch("upload_policy").fetch("mode") == "preserve_remote"
            "- Remote media references and metadata were verified. Media remains at its existing origins."
          else
            "- Local upload originals were checked byte for byte."
          end
        ),
        "",
        *(
          if summary["content"]
            [
              "## Content and account decisions",
              "",
              *ContentPolicy.lines(summary.fetch("content")),
              "",
              "Populated tables outside merger coverage — #{@plan.data.fetch("coverage", {}).values.count("unrecognized and omitted")}.",
              "",
            ]
          else
            []
          end
        ),
        "## Verification",
        "",
        "- Merger’s check — Passed.",
        "- Backup restore test — Recorded separately.",
      ]
    end

    def routes(summary)
      unless summary.fetch("routes")
        return [
          "This run predates category routing evidence. The existing preview and ledger are the available evidence for routing.",
        ]
      end
      lines = [
        "| Source category | Final destination | Discussions moved |",
        "| --- | --- | ---: |",
      ]
      summary
        .fetch("routes")
        .each do |source, destination, count|
          lines << "| #{category_label(source)} | #{category_label(destination)} | #{count} |"
        end
      aggregate = summary.fetch("other_discussions")
      lines << "| All other discussions | — | #{aggregate} |" if aggregate.positive?
      lines
    end

    def category_label(path)
      path
        .map do |name|
          name.gsub(/[[:space:]]+/, " ").gsub(/[[:punct:]]/) { |character| "\\#{character}" }
        end
        .join(" › ")
    end

    def exclusions(summary)
      lines = []
      if counts = summary.fetch("exclusions")
        lines << "- Discussions excluded — #{counts.fetch("discussion", 0)}"
        lines << "- Private messages excluded — #{counts.fetch("private_message", 0)}"
        lines << "- Category descriptions omitted — #{counts.fetch("category_description", 0)}"
      else
        lines << "- Source topics excluded — #{@plan.excluded_ids.size}"
      end
      findings = @plan.data.fetch("source_findings", {})
      lines << "- Posts without a source topic omitted — #{findings.fetch("posts_without_topics", 0)}"
      lines << "- Draft and moderation records omitted — #{findings.fetch("pending_entities", {}).values.sum}"
      omitted_plugins = findings.fetch("omitted_plugin_entities", {}).values.sum
      lines << "- Inactive plugin records omitted — #{omitted_plugins}" if omitted_plugins.positive?
      lines
    end
  end

  class ReportSummary
    def initialize(plan)
      @plan = plan
      @source_categories = plan.data["source_categories"]
      @categories_by_path =
        plan.categories.values.index_by { |category| category.fetch("path") } if @source_categories
    end

    def build(posts:, uploads:)
      discussions =
        @plan.topics.values.select { |topic| topic.fetch("action") == "copy_discussion" }
      counts = Hash.new(0)
      aggregate = 0
      if @source_categories
        discussions.each do |topic|
          destination = @plan.categories.fetch(topic.fetch("destination_key")).fetch("path")
          source_id = topic.fetch("source_category_id").to_s
          if public_route?(topic, source_id, destination)
            counts[[@source_categories.fetch(source_id).fetch("path"), destination]] += 1
          else
            aggregate += 1
          end
        end
      end
      {
        "discussions" => discussions.size,
        "private_messages" =>
          @plan.topics.values.count { |topic| topic.fetch("action") == "copy_private_message" },
        "posts" => posts,
        "uploads" => uploads,
        "routes" =>
          @source_categories &&
            counts.sort.map { |(source, destination), count| [source, destination, count] },
        "other_discussions" => aggregate,
        "exclusions" => @source_categories && exclusion_counts,
      }
    end

    private

    def exclusion_counts
      descriptions =
        @source_categories.values.filter_map { |category| category["description_topic_id"] }.to_set
      @plan
        .excluded_ids
        .map do |id|
          topic = @plan.topic(id)
          case topic["exclusion_reason"]
          when "private_messages_disabled"
            "private_message"
          when "obsolete_category_description"
            "category_description"
          when "topic_excluded", "category_excluded"
            "discussion"
          else
            if topic.fetch("source_archetype") == "private_message"
              "private_message"
            elsif descriptions.include?(id)
              "category_description"
            else
              "discussion"
            end
          end
        end
        .tally
    end

    def public_route?(topic, source_id, destination)
      access = @plan.data.fetch("login_required")
      state = topic.fetch("source_state")
      unless access.fetch("source") == false && access.fetch("destination") == false &&
               topic.fetch("source_archetype") == "regular" &&
               topic.fetch("source_shared_draft") == false && state.fetch("visible") == true &&
               state.fetch("deleted_at").nil?
        return false
      end

      source = @source_categories[source_id]
      return false unless source
      while source
        return false unless source.fetch("access") == "public"
        parent = source.fetch("parent_id")
        source = parent && @source_categories.fetch(parent)
      end
      (1..destination.length).all? do |length|
        @categories_by_path.fetch(destination.first(length)).fetch("access") == "public"
      end
    end
  end
end
