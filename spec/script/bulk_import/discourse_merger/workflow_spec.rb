# frozen_string_literal: true

require "tmpdir"
require "pg"
require "stringio"
require_relative "../../../../script/bulk_import/discourse_merger/cli"
require_relative "../../../../script/bulk_import/discourse_merger/runner"
require_relative "../../../../script/bulk_import/discourse_merger/support"
require_relative "../../../../script/bulk_import/discourse_merger/verifier"

RSpec.describe BulkImport::DiscourseMerge::CLI do
  around do |example|
    Dir.mktmpdir do |directory|
      @directory = Pathname.new(directory)
      @directory.join("merge.yml").write(
        {
          "source" => {
            "dbname" => "disposable_source",
            "host" => directory,
          },
          "destination" => {
            "dbname" => "disposable_destination",
            "host" => directory,
          },
          "source_url" => "https://source.example",
          "destination_url" => "https://destination.example",
          "upload_mode" => "preserve_remote",
        }.to_yaml,
      )
      example.run
    end
  end

  it "reports PostgreSQL setup failure without requiring mappings" do
    expect {
      expect(
        described_class.run(["preflight", "--setup-only", "--directory", @directory.to_s]),
      ).to eq(1)
    }.to output(
      /Failed during destination connection.*Cannot connect.*check merge.yml.*Log:/m,
    ).to_stderr
    report = JSON.parse(@directory.join("preflight-setup.json").read)
    expect(report).to include(
      "status" => "blocked",
      "scope" => "setup",
      "stage" => "destination connection",
    )
    expect(@directory.join("preflight.json")).not_to exist
  end

  it "rejects a changed reviewed plan before starting an import" do
    plan = @directory.join("plan.json")
    plan.write('{"version":1}')
    reviewed = Digest::SHA256.file(plan).hexdigest
    plan.write('{"version":2}')
    expect {
      expect(
        described_class.run(["apply", "--directory", @directory.to_s, "--plan-sha256", reviewed]),
      ).to eq(1)
    }.to output(
      /Failed during reviewed plan and run guard.*SHA-256 differs.*Log:.*Correct the reported input/m,
    ).to_stderr
    expect(@directory.join("active-run.json")).not_to exist
  end

  it "requires access approval before connecting to either database" do
    plan = @directory.join("plan.json")
    plan.write(JSON.generate("group_access" => { "expansions" => [{ "id" => 1 }] }))
    reviewed = Digest::SHA256.file(plan).hexdigest

    expect {
      expect(
        described_class.run(["apply", "--directory", @directory.to_s, "--plan-sha256", reviewed]),
      ).to eq(1)
    }.to output(/reviewed plan and run guard.*--approve-access-changes/m).to_stderr
    expect(@directory.join("active-run.json")).not_to exist
  end

  it "rejects edited mapping files before connecting to the database" do
    mapping = @directory.join("mappings/categories.csv")
    mapping.dirname.mkdir
    mapping.write("Tutorials,copy\n")
    plan = @directory.join("plan.json")
    plan.write(
      JSON.generate(
        "inputs_sha256" => BulkImport::DiscourseMerge::Planner.input_hashes(@directory),
      ),
    )
    reviewed = Digest::SHA256.file(plan).hexdigest
    mapping.write("Tutorials,exclude\n")

    expect {
      expect(
        described_class.run(["apply", "--directory", @directory.to_s, "--plan-sha256", reviewed]),
      ).to eq(1)
    }.to output(/reviewed mapping inputs.*regenerate and review the plan/m).to_stderr
    expect(@directory.join("active-run.json")).not_to exist
    expect(@directory.join("runs")).not_to exist
  end

  it "requires a fresh plan after the staff role selection changes", workbook: true do
    if Gem::Specification.find_all_by_name("rubyXL").none?
      skip "Install the generic_import bundle group to run workbook specs"
    end
    require "rubyXL"

    workbook = @directory.join("mappings.xlsx")
    book = RubyXL::Workbook.new
    book[0].add_cell(1, 1, "Keep source staff roles")
    book.write(workbook.to_s)
    plan = @directory.join("plan.json")
    plan.write(
      JSON.generate(
        "policy" => {
          "source_staff_roles" => "preserve",
        },
        "inputs_sha256" => BulkImport::DiscourseMerge::Planner.input_hashes(@directory),
      ),
    )
    reviewed = Digest::SHA256.file(plan).hexdigest

    book[0].add_cell(1, 1, "Import staff as regular users")
    book.write(workbook.to_s)

    expect {
      expect(
        described_class.run(["apply", "--directory", @directory.to_s, "--plan-sha256", reviewed]),
      ).to eq(1)
    }.to output(/reviewed mapping inputs.*regenerate and review the plan/m).to_stderr
    expect(@directory.join("active-run.json")).not_to exist
  end

  it "runs preflight before printing an apply command with the required approval" do
    runner = instance_double(BulkImport::DiscourseMerge::Runner)
    allow(BulkImport::DiscourseMerge::Runner).to receive(:new).and_return(runner)
    allow(runner).to receive(:preflight).with(write_plan: true) do
      plan = { "group_access" => { "expansions" => [{ "id" => 1 }] } }
      @directory.join("plan.json").write(JSON.generate(plan))
      plan
    end

    expect {
      expect(described_class.run(["plan", "--directory", @directory.to_s])).to eq(0)
    }.to output(
      /Review .*preview.md.*apply.*--plan-sha256 [a-f0-9]{64} --approve-access-changes/m,
    ).to_stdout
  end

  it "recommends an upload-inclusive backup when the result uses local storage" do
    @directory.join("plan.json").write(JSON.generate("upload_policy" => { "mode" => "copy" }))
    expect {
      described_class.report_backup(@directory, BulkImport::DiscourseMerge::Progress.new)
    }.to output(%r{script/discourse backup$}).to_stdout
  end

  it "recommends a SQL-only backup for a remote-only result" do
    @directory.join("plan.json").write(
      JSON.generate("upload_policy" => { "mode" => "preserve_remote" }),
    )
    expect {
      described_class.report_backup(@directory, BulkImport::DiscourseMerge::Progress.new)
    }.to output(%r{media origins.*script/discourse backup --sql-only$}m).to_stdout
  end

  it "keeps a failed import guarded and directs the operator to recover all baseline components" do
    run = @directory.join("runs/example")
    run.mkpath
    marker = @directory.join("active-run.json")
    state = { "status" => "failed", "mutation_started" => true, "run_dir" => run.to_s }
    BulkImport::DiscourseMerge::Configuration.write(marker, state)

    expect {
      expect(
        described_class.run(["apply", "--directory", @directory.to_s, "--plan-sha256", "0" * 64]),
      ).to eq(1)
    }.to output(
      /active run.*Log:.*recover the destination PostgreSQL, local storage, and Redis baseline/m,
    ).to_stderr
    expect(JSON.parse(marker.read)).to eq(state)
    expect(@directory.join("logs").glob("apply-*.log").sole.read).to include(
      "recover the destination",
    )
  end
end

RSpec.describe BulkImport::DiscourseMerge::Runner, "#preflight" do
  it "reports which sites are connected before mapping decisions are needed" do
    Dir.mktmpdir do |directory|
      project = Pathname.new(directory)
      configuration =
        instance_double(
          BulkImport::DiscourseMerge::Configuration,
          directory: project,
          upload_mode: "preserve_remote",
        )
      output = StringIO.new
      progress = BulkImport::DiscourseMerge::Progress.new(output: output)
      runner = described_class.new(configuration, progress: progress)
      source = instance_double(PG::Connection, db: "incoming_forum", close: nil)
      destination = instance_double(PG::Connection, db: "discourse", close: nil)
      allow(runner).to receive(:connect).with("destination").and_return(destination)
      allow(runner).to receive(:open_source).with(destination).and_return(source)
      allow(runner).to receive(:validate_setup!).with(source, destination)
      allow(source).to receive(:exec).with(/site_settings.*title/m).and_return(
        [{ "title" => "Source Forum", "topics" => "9107" }],
      )
      allow(destination).to receive(:exec).with(/site_settings.*title/m).and_return(
        [{ "title" => nil, "topics" => "6" }],
      )

      runner.preflight(setup_only: true)

      report = JSON.parse(project.join("preflight-setup.json").read)
      expect(report.fetch("sites").fetch("source")).to eq(
        "database" => "incoming_forum",
        "title" => "Source Forum",
        "topics" => 9107,
      )
      expect(output.string).to include(
        "Destination database discourse, site title \"Discourse\", 6 topics",
      )
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Runner, "#apply" do
  it "archives the reviewed workbook before starting the importer and retains it on failure",
     workbook: true do
    if Gem::Specification.find_all_by_name("rubyXL").none?
      skip "Install the generic_import bundle group to run workbook specs"
    end
    require "rubyXL"

    Dir.mktmpdir do |directory|
      project = Pathname.new(directory)
      project.join("merge.yml").write("namespace: harbor\n")
      workbook = project.join("mappings.xlsx")
      book = RubyXL::Workbook.new
      book[0].add_cell(0, 0, "Harbor Resources")
      book.write(workbook.to_s)
      workbook_bytes = workbook.binread
      configuration = instance_double(BulkImport::DiscourseMerge::Configuration, directory: project)
      progress = BulkImport::DiscourseMerge::Progress.new(output: StringIO.new)
      runner = described_class.new(configuration, progress: progress)
      plan = {
        "format_version" => 1,
        "topics" => [],
        "categories" => [],
        "inputs_sha256" => BulkImport::DiscourseMerge::Planner.input_hashes(project),
      }
      reviewed = JSON.generate(plan)
      project.join("plan.json").write(reviewed)
      digest = Digest::SHA256.hexdigest(reviewed)
      lock = instance_double(PG::Result, getvalue: "t")
      connection = instance_double(PG::Connection, exec: lock, close: nil)
      allow(runner).to receive(:connect).with("destination").and_return(connection)
      allow(runner).to receive(:open_source).and_return(connection)
      allow(runner).to receive(:validate_setup!)
      allow(runner).to receive(:validate_preflight!)
      allow(runner).to receive(:fingerprints).and_return({})
      allow(runner).to receive(:source_fingerprints).and_return({})
      allow(BulkImport::DiscourseMerge::Environment).to receive(:check!)
      allow(runner).to receive(:capture_inventory).and_return({})
      planner = instance_double(BulkImport::DiscourseMerge::Planner, build: plan)
      allow(BulkImport::DiscourseMerge::Planner).to receive(:new).and_return(planner)
      require_relative "../../../../script/bulk_import/discourse_merger/merger" if defined?(Rails)
      importer = instance_double("BulkImport::DiscourseMerge::Merger")
      merger = class_double("BulkImport::DiscourseMerge::Merger").as_stubbed_const
      class_double("Sidekiq", pause!: nil).as_stubbed_const
      allow(merger).to receive(:new).and_return(importer)
      allow(importer).to receive(:start) do
        workbook.write("Updated after checkpoint")
        progress.start("topics and posts")
        raise BulkImport::DiscourseMerge::Error, "disposable import failure"
      end

      expect { runner.apply(digest) }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /disposable import failure/,
      )
      state = JSON.parse(project.join("active-run.json").read)
      run = Pathname.new(state.fetch("run_dir"))
      expect(state).to include(
        "status" => "failed",
        "mutation_started" => true,
        "last_stage" => "topics and posts",
      )
      expect(run.join("plan.json").binread).to eq(reviewed)
      archive = run.join("mapping-inputs/mappings.xlsx")
      expect(archive.binread).to eq(workbook_bytes)
      expect(archive.stat.mode & 0o777).to eq(0o600)
      expect(JSON.parse(run.join("state.json").read)).to eq(state)
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Verifier, "#verify_posts" do
  it "checks the rewritten body and treats an unset locker as unlocked" do
    plan =
      BulkImport::DiscourseMerge::Plan.new(
        {
          "format_version" => 1,
          "categories" => [],
          "topics" => [{ "source_topic_id" => 12, "action" => "copy_discussion" }],
          "policy" => {
            "source_host" => "source.example",
            "source_url" => "https://source.example",
            "destination_host" => "destination.example",
            "destination_url" => "https://destination.example",
          },
          "upload_policy" => {
            "mode" => "preserve_remote",
          },
        },
      )
    source = instance_double(PG::Connection)
    raw = %([quote="incoming, post:1, topic:12"]\n@incoming /t/12 /uploads/original.png\n[/quote])
    allow(source).to receive(:transaction_status).and_return(PG::PQTRANS_INTRANS)
    allow(source).to receive(:exec).and_return([])
    allow(source).to receive(:exec).with(/FETCH/).and_return(
      [{ "id" => "11", "topic_id" => "12", "user_id" => "13", "raw" => raw }],
    )
    maps = { users: { 13 => 23 }, posts: { 11 => 21 }, topics: { 12 => 22 }, categories: {} }
    references =
      BulkImport::DiscourseMerge::References.from_plan(
        plan,
        maps,
        usernames: {
          "incoming" => "renamed",
        },
        group_names: {
        },
        media_urls: {
          "/uploads/original.png" => "https://cdn.example/retained.png",
        },
      )
    context =
      instance_double(
        BulkImport::DiscourseMerge::VerificationContext,
        source_raw_connection: source,
        category_keys: {
        },
        maps: maps,
        references: references,
      )
    post =
      Struct.new(
        :id,
        :topic_id,
        :user_id,
        :created_at,
        :updated_at,
        :deleted_at,
        :hidden,
        :user_deleted,
        :locked_by_id,
        :raw,
      ).new(
        21,
        22,
        23,
        nil,
        nil,
        nil,
        false,
        false,
        nil,
        %([quote="renamed, post:1, topic:22"]\n@renamed https://destination.example/t/22 https://cdn.example/retained.png\n[/quote]),
      )
    destination = class_double("Post").as_stubbed_const
    allow(destination).to receive(:with_deleted).and_return(destination)
    allow(destination).to receive(:where).with(id: [21]).and_return([post])
    Dir.mktmpdir do |directory|
      verifier = described_class.new(context, plan, Pathname.new(directory))
      expect { verifier.verify_posts }.not_to raise_error
      post.locked_by_id = -1
      expect { verifier.verify_posts }.to raise_error(/post_11_lock/)
      post.locked_by_id = nil
      post.raw = "Changed body"
      expect { verifier.verify_posts }.to raise_error(/post_11_body/)
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Environment, ".check!" do
  it "identifies an unreadable supervisor status separately from a running service" do
    success = instance_double(Process::Status, success?: true)
    failure = instance_double(Process::Status, success?: false)
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with("/etc/service/unicorn").and_return(true)
    allow(File).to receive(:directory?).with("/etc/service/pitchfork").and_return(false)
    allow(File).to receive(:directory?).with("/etc/service/sidekiq").and_return(false)
    allow(Open3).to receive(:capture2).with("ps", "-eo", "comm=,args=").and_return(["", success])
    allow(Open3).to receive(:capture3).with("sv", "status", "/etc/service/unicorn").and_return(
      ["warning: unable to open supervise/status: access denied", "", failure],
      ["run: /etc/service/unicorn: (pid 456) 1s", "", success],
      ["down: /etc/service/unicorn: 1s", "", success],
    )

    expect { described_class.check! }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Cannot read stopped status.*access denied/,
    )
    expect { described_class.check! }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /service is running.*sv stop/,
    )
    expect(described_class.check!).to eq(true)
  end
end
