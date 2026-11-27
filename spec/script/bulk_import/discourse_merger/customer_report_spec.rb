# frozen_string_literal: true

require "tmpdir"
require_relative "../../../../script/bulk_import/discourse_merger/cli"

require_relative "../../../../script/bulk_import/discourse_merger/customer_report"

RSpec.describe BulkImport::DiscourseMerge::CLI, ".run" do
  around do |example|
    Dir.mktmpdir do |directory|
      @project = Pathname.new(directory)
      @run = @project.join("runs/harbor")
      @run.mkpath
      example.run
    end
  end

  def category(id, name, restricted: false)
    {
      "id" => id.to_s,
      "name" => name,
      "topic_id" => (id + 300).to_s,
      "read_restricted" => restricted ? "t" : "f",
    }
  end

  def discussion(id, category_id, title, **attributes)
    {
      "id" => id.to_s,
      "category_id" => category_id.to_s,
      "title" => title,
      "visible" => "t",
      "archetype" => "regular",
    }.merge(attributes.transform_keys(&:to_s))
  end

  def record_run(plan, status: "verified", account_ledger: {})
    topics =
      plan
        .fetch("topics")
        .reject { |topic| %w[exclude exclude_obsolete_description].include?(topic.fetch("action")) }
    topic_ids = topics.map { |topic| topic.fetch("source_topic_id") }
    ledger = {
      "stage" => "complete",
      "topics" => topic_ids.to_h { |id| [id, id + 5000] },
      "posts" => {
        "501" => 8511,
      },
      "uploads" => {
        "28" => 712,
      },
      "category_keys" =>
        plan
          .fetch("categories")
          .each_with_index
          .to_h { |category, index| [category.fetch("key"), index + 20] },
    }
    ledger.merge!(account_ledger)
    @run.join("plan.json").write(JSON.generate(plan))
    @run.join("ledger.json").write(JSON.generate(ledger))
    hashes =
      %w[plan.json ledger.json].to_h do |name|
        [name, Digest::SHA256.file(@run.join(name)).hexdigest]
      end
    checks =
      %w[
        complete_topic_map
        excluded_topics_unmapped
        complete_post_map
        complete_upload_map
        existing_destination_records_preserved
        source_records_unchanged
      ].to_h { |name| [name, true] }
    checks.merge!(topic_ids.to_h { |id| ["topic_#{id}_destination", true] })
    checks["status"] = "passed"
    if plan.key?("source_categories")
      checks["account_outcomes"] = true if ledger.key?("account_outcomes")
      checks["evidence_sha256"] = hashes
      checks["report_summary"] = BulkImport::DiscourseMerge::ReportSummary.new(
        BulkImport::DiscourseMerge::Plan.new(plan),
      ).build(posts: ledger.fetch("posts").size, uploads: ledger.fetch("uploads").size)
      if plan.fetch("format_version") >= 3
        if plan["merge_member_activity"]
          checks["matched_member_summaries"] = true
          checks["matched_member_visit_dates"] = true
        end
        checks["reviewed_content"] = true
        checks["reviewed_destination_content_settings"] = true
        checks.fetch("report_summary")[
          "content"
        ] = BulkImport::DiscourseMerge::ContentPolicy.summary(plan.fetch("content"))
      end
      checks["destination_login_required"] = true
      ledger
        .fetch("category_keys")
        .each_value do |id|
          %w[name parent read_access].each { |field| checks["category_#{id}_#{field}"] = true }
        end
    end
    @run.join("verification.json").write(JSON.generate(checks))
    @project.join("active-run.json").write(
      JSON.generate(
        "status" => status,
        "run_dir" => "/previous-location/runs/harbor",
        "plan_sha256" => hashes.fetch("plan.json"),
      ),
    )
  end

  def legacy_plan
    {
      "format_version" => 1,
      "categories" => [],
      "topics" => [{ "source_topic_id" => 17, "action" => "copy_discussion" }],
      "upload_policy" => {
        "mode" => "copy",
      },
    }
  end

  it "repeats the same private account CSV from verified evidence" do
    plan =
      legacy_plan.merge(
        "topics" => [],
        "source_categories" => {
        },
        "login_required" => {
          "source" => false,
          "destination" => false,
        },
        "source_findings" => {
          "account_matches" => [
            { "source_user_id" => 1, "destination_user_id" => 11 },
            { "source_user_id" => 2, "destination_user_id" => 12 },
          ],
        },
        "matched_avatars" => [
          { "destination_user_id" => 11, "username" => "Sam_2", "sources" => { "1" => "Alex" } },
          { "destination_user_id" => 12, "username" => "Kim", "sources" => { "2" => "Kim" } },
        ],
      )
    record_run(
      plan,
      account_ledger: {
        "users" => {
          "1" => 11,
          "2" => 12,
          "3" => 13,
          "-4" => 14,
        },
        "username_change_sources" => {
          "Alex" => 1,
          "Lee" => 3,
          "Bot" => -4,
        },
        "username_changes" => {
          "Alex" => "Sam_2",
          "Lee" => "Lee_3",
          "Bot" => "Bot_1",
        },
      },
    )
    path = @project.join("account-outcomes.csv")
    2.times do
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(0)
      expect(CSV.read(path).drop(1)).to eq(
        [
          ["Alex", "Sam_2", "Matched by email", "true"],
          ["Kim", "Kim", "Matched by email", "false"],
          ["Lee", "Lee_3", "Created after username collision", "true"],
        ],
      )
      expect(path.stat.mode & 0o777).to eq(0o600)
    end
  end

  it "requires verified account outcomes before reporting directly recorded names" do
    plan =
      legacy_plan.merge(
        "topics" => [],
        "source_categories" => {
        },
        "login_required" => {
          "source" => false,
          "destination" => false,
        },
      )
    record_run(
      plan,
      account_ledger: {
        "account_outcomes" => {
          "3" => {
            "source_username" => "Lee",
            "final_username" => "Lee_2",
            "reason" => "username_collision",
          },
        },
      },
    )
    expect(described_class.run(["report", "--directory", @project.to_s])).to eq(0)
    expect(CSV.read(@project.join("account-outcomes.csv")).drop(1)).to eq(
      [["Lee", "Lee_2", "Created after username collision", "true"]],
    )
    verification = @run.join("verification.json")
    verification.write(JSON.generate(JSON.parse(verification.read).except("account_outcomes")))
    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(1)
    }.to output(/requires verified account outcomes/).to_stderr
  end

  it "reports verified category and topic-exception routes from the walkthrough workbook",
     workbook: true do
    if Gem::Specification.find_all_by_name("rubyXL").none?
      skip "Install the generic_import bundle group to run workbook specs"
    end

    incoming_secret = category(4, "Restricted Bench", restricted: true)
    destination_secret = category(23, "Workshop Staff Archive", restricted: true)
    secret_discussion = discussion(19, 4, "Staff tool inventory")
    exception = discussion(11, 1, "Calibrating the tide gauge")
    categories = [
      category(1, "Tutorials"),
      category(2, "Questions"),
      category(3, "Field Notes"),
      incoming_secret,
    ]
    inventory = {
      "source" => {
        "database" => "harbor_tools",
        "categories" => categories,
        "grants" => [{ "category_id" => "4", "group_id" => "3", "permission_type" => "1" }],
        "groups" => [{ "id" => "47", "name" => "harbor_editors", "automatic" => "f" }],
        "topics" => [
          exception,
          discussion(12, 1, "Using a spoke wrench"),
          discussion(13, 2, "Which hex key fits?"),
          discussion(14, 2, "Replacing a vise jaw"),
          discussion(15, 2, "Unlisted repair notes", visible: "f"),
          discussion(16, 2, "Deleted repair notes", deleted_at: "2026-05-01 10:00:00"),
          discussion(17, 2, "Shared draft repair notes", shared_draft: "t"),
          discussion(18, 3, "Tools for the spring meetup"),
          secret_discussion,
          discussion(20, 2, "Private workshop routing"),
          discussion(21, 3, "Superseded field notes"),
          { "id" => "22", "archetype" => "private_message" },
          *categories.map { |item| discussion(item.fetch("topic_id"), item.fetch("id"), "About") },
        ],
        "privileged_accounts" => [
          {
            "id" => "77",
            "username" => "harbor_mechanic",
            "email" => "mechanic@harbor-tools.example",
          },
        ],
        "pending_entities" => {
          "drafts" => 2,
          "reviewables" => 3,
        },
        "posts_without_topics" => 1,
      },
      "destination" => {
        "database" => "cedar_workshop",
        "categories" => [
          category(21, "Product Support"),
          category(22, "Community Archive"),
          destination_secret,
        ],
        "grants" => [{ "category_id" => "23", "group_id" => "3", "permission_type" => "1" }],
      },
    }
    @project.join("merge.yml").write(
      {
        "source" => {
          "dbname" => "harbor_tools",
        },
        "destination" => {
          "dbname" => "cedar_workshop",
        },
        "source_url" => "https://harbor-tools.example",
        "destination_url" => "https://cedar-workshop.example",
        "upload_mode" => "preserve_remote",
      }.to_yaml,
    )
    configuration = BulkImport::DiscourseMerge::Configuration.new(@project)
    BulkImport::DiscourseMerge::TemplateExporter.new(configuration, inventory).export
    workbook = @project.join("mappings.xlsx")
    expect {
      expect(described_class.run(["export-workbook", "--directory", @project.to_s])).to eq(0)
    }.to output(/Edit .*mappings.xlsx/).to_stdout
    book = RubyXL::Parser.parse(workbook.to_s)
    expect(book["Category Mapping"][1][2].value).to eq("Keep category")
    expect(book["Group Mapping"][1][2].value).to eq("Match identical group")
    expect(book["Review"][2][1].value).to eq("0")
    book["New Categories"][1][1].change_contents("Harbor Resources")
    category_mapping = book["Category Mapping"]
    category_mapping[1][3].change_contents("Harbor Resources [N001]")
    category_mapping[2][2].change_contents("Use existing category")
    category_mapping[2][5].change_contents("Product Support [D21]")
    category_mapping[3][2].change_contents("Move discussions only")
    category_mapping[3][5].change_contents("Harbor Resources [N001]")
    topic_exceptions = book["Topic Exceptions"]
    topic_exceptions[1][0].change_contents("#{exception.fetch("title")} [T11]")
    topic_exceptions[1][1].change_contents("Move discussion")
    topic_exceptions[1][2].change_contents("Community Archive [D22]")
    topic_exceptions[2][0].change_contents("Private workshop routing [T20]")
    topic_exceptions[2][1].change_contents("Move discussion")
    topic_exceptions[2][2].change_contents("Workshop Staff Archive [D23]")
    topic_exceptions[3][0].change_contents("Superseded field notes [T21]")
    topic_exceptions[3][1].change_contents("Exclude")
    book.write(workbook.to_s)
    planner = BulkImport::DiscourseMerge::Planner.new(configuration, inventory)
    plan = planner.build
    planner.write(plan)
    expect(@project.join("preview.md").read).to include("Harbor Resources > Tutorials")
    record_run(plan)
    @project.join("merge.yml").unlink

    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(0)
    }.to output(/Customer report: .*customer-report.md/).to_stdout

    report = @project.join("customer-report.md").read
    expect(report.lines.grep(/\A\|/).map(&:strip)).to eq(
      [
        "| Source category | Final destination | Discussions moved |",
        "| --- | --- | ---: |",
        "| Field Notes | Harbor Resources | 1 |",
        "| Questions | Product Support | 2 |",
        "| Tutorials | Community Archive | 1 |",
        "| Tutorials | Harbor Resources › Tutorials | 1 |",
        "| All other discussions | — | 5 |",
      ],
    )
    expect(report).to include(
      "Discussions moved — 10",
      "Private messages moved — 1",
      "Discussions excluded — 1",
      "Category descriptions omitted — 2",
      "Draft and moderation records omitted — 5",
      "Remote media references and metadata were verified",
      "Merger’s check — Passed",
      "Backup restore test — Recorded separately",
    )
    expect(report).not_to include(
      incoming_secret.fetch("name"),
      destination_secret.fetch("name"),
      secret_discussion.fetch("title"),
      exception.fetch("title"),
      inventory.dig("source", "privileged_accounts", 0, "email"),
      "8511",
    )
    # Older verified runs can still reconstruct their report from the individual checks.
    record_run(
      plan.except("merge_member_activity", "rewrite_letter_avatars").merge("format_version" => 2),
    )
    expect { described_class.run(["report", "--directory", @project.to_s]) }.to output(
      /Customer report/,
    ).to_stdout
    historical_report = @project.join("customer-report.md").read
    checks = JSON.parse(@run.join("verification.json").read)
    checks.delete("report_summary")
    @run.join("verification.json").write(JSON.generate(checks))
    expect { described_class.run(["report", "--directory", @project.to_s]) }.to output(
      /Customer report/,
    ).to_stdout
    expect(@project.join("customer-report.md").read).to eq(historical_report)
  end

  it "reports totals for older evidence and points to the preview and ledger for routing" do
    record_run(legacy_plan)
    ledger = JSON.parse(@run.join("ledger.json").read)
    ledger.fetch("posts")["999"] = 888
    @run.join("ledger.json").write(JSON.generate(ledger))

    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(0)
    }.to output(/Customer report/).to_stdout

    expect(@project.join("customer-report.md").read).to include(
      "Discussions moved — 1",
      "Verified post total unavailable",
      "Verified upload total unavailable",
      "The existing preview and ledger are the available evidence",
      "Local upload originals were checked byte for byte",
    )
  end

  it "refuses to report a run with failed verification even when apply previously passed" do
    record_run(legacy_plan)
    @run.join("verification.json").write(JSON.generate("status" => "failed"))

    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(1)
    }.to output(/requires a final ledger and passing verification/).to_stderr
    expect(@project.join("customer-report.md")).not_to exist
  end

  it "refuses to report while apply is still in progress" do
    record_run(legacy_plan, status: "applying")

    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(1)
    }.to output(/requires a successfully verified apply/).to_stderr
    expect(@project.join("customer-report.md")).not_to exist
  end

  it "refuses to report when the verified ledger was changed" do
    record_run(legacy_plan.merge("source_categories" => {}, "topics" => []))
    @run.join("ledger.json").open("a") { |file| file.puts }

    expect {
      expect(described_class.run(["report", "--directory", @project.to_s])).to eq(1)
    }.to output(/ledger must match the passing verification/).to_stderr
    expect(@project.join("customer-report.md")).not_to exist
  end
end
