# frozen_string_literal: true
require "tmpdir"
require "pg"
require_relative "../../../../script/bulk_import/discourse_merger/runner"
require_relative "../../../../script/bulk_import/discourse_merger/planner"
require_relative "../../../../script/bulk_import/discourse_merger/support"

RSpec.describe BulkImport::DiscourseMerge::Planner do
  def rewrite
    path = @configuration.directory.join("mappings/categories.csv")
    table = CSV.read(path, headers: true)
    yield table
    CSV.open(path, "w", headers: table.headers, write_headers: true) do |csv|
      table.each { |row| csv << row }
    end
  end

  around do |example|
    Dir.mktmpdir do |directory|
      File.write(
        File.join(directory, "merge.yml"),
        {
          "source" => {
            "dbname" => "incoming",
          },
          "destination" => {
            "dbname" => "destination",
          },
          "source_url" => "https://incoming.example",
          "destination_url" => "https://destination.example",
          "source_upload_root" => "/source",
          "destination_upload_root" => "/destination",
        }.to_yaml,
      )
      @configuration = BulkImport::DiscourseMerge::Configuration.new(directory)
      category = {
        "id" => "1",
        "name" => "Products",
        "parent_category_id" => nil,
        "topic_id" => "101",
        "read_restricted" => "f",
      }
      grant = { "category_id" => "1", "group_id" => "0", "permission_type" => "1" }
      @inventory = {
        "source" => {
          "database" => "incoming",
          "categories" => [category],
          "topics" => [
            { "id" => "10", "category_id" => "1", "archetype" => "regular", "visible" => "t" },
            { "id" => "101", "category_id" => "1", "archetype" => "regular" },
          ],
          "grants" => [grant],
        },
        "destination" => {
          "database" => "destination",
          "categories" => [category.merge("name" => "Support")],
          "grants" => [grant],
        },
      }
      BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).export
      if !Gem::Specification.find_all_by_name("rubyXL").any? && example.metadata[:workbook]
        skip "Install the generic_import bundle group to run workbook specs"
      end
      example.run
    end
  end

  it "binds remote metadata, account matches and omission counts to the reviewed plan" do
    @configuration
      .directory
      .join("merge.yml")
      .write(
        @configuration
          .data
          .except("source_upload_root", "destination_upload_root")
          .merge("upload_mode" => "preserve_remote", "import_tags" => false)
          .to_yaml,
      )
    @configuration = BulkImport::DiscourseMerge::Configuration.new(@configuration.directory)
    @inventory["source"]["uploads"] = [
      { "id" => "1", "url" => "/uploads/a.png", "filesize" => "12", "sha1" => "abc" },
    ]
    @inventory["source"]["optimized_images"] = [
      { "id" => "2", "url" => "https://cdn.example/thumb.png" },
    ]
    @inventory["source"]["account_matches"] = [
      { "source_user_id" => 1, "destination_user_id" => 2 },
    ]
    @inventory["source"]["pending_entities"] = { "drafts" => 15, "reviewables" => 310 }
    planner = described_class.new(@configuration, @inventory)
    plan = planner.build
    expect(plan.dig("upload_policy", "mode")).to eq("preserve_remote")
    expect(plan.dig("policy", "import_tags")).to eq(false)
    planner.write(plan)
    expect(@configuration.directory.join("preview.md").read).to include(
      "Matched accounts: 1",
      "drafts",
      "310",
      "file bytes are not verified",
    )
    @inventory["source"]["optimized_images"][0]["url"] = "https://cdn.example/changed.png"
    expect(planner.build.fetch("inventory_sha256")).not_to eq(plan.fetch("inventory_sha256"))
  end

  it "binds a completed native preparation and rejects a different final snapshot" do
    require_relative "../../../../script/bulk_import/native_upload_store"
    dir = @configuration.directory
    dir.join("merge.yml").write(@configuration.data.merge("upload_mode" => "preuploaded").to_yaml)
    config = BulkImport::DiscourseMerge::Configuration.new(dir)
    @inventory.each_value { |side| side.merge!("uploads" => [], "optimized_images" => []) }
    planner = described_class.new(config, @inventory)
    expect { planner.build }.to raise_error(/Run prepare-uploads/)
    snapshot = instance_double(BulkImport::DiscourseMerge::Inventory)
    allow(snapshot).to receive(:connect).and_yield(instance_double("PG::Connection", exec: nil))
    allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each_batch)
    store =
      instance_double(
        BulkImport::NativeUploadStore,
        check!: nil,
        target: {
          "bucket" => "final",
          "prefix" => "uploads/hosted",
        },
      )
    receipt = dir.join(BulkImport::DiscourseMerge::PreparedUploads::FILE)
    BulkImport::DiscourseMerge::PreparedUploads.open(receipt, readonly: false) do |state|
      state.prepare!(
        config,
        store,
        instance_double(BulkImport::DiscourseMerge::Progress, say: nil),
        workers: 1,
        inventory: snapshot,
      )
    end
    plan = planner.build
    expect(plan.fetch("format_version")).to eq(4)
    expect(plan.dig("upload_policy", "receipt_sha256")).to eq(
      Digest::SHA256.file(receipt).hexdigest,
    )
    planner.write(plan)
    expect(dir.join("preview.md").read).to include("s3://final/uploads/hosted")
    @inventory["source"]["uploads"] << { "id" => "1" }
    expect { planner.build }.to raise_error(/inventory changed/)
  end

  it "previews retained SQL records and counts only incoming files needing target receipts" do
    dir = @configuration.directory
    dir.join("merge.yml").write(
      @configuration
        .data
        .except("source_upload_root")
        .merge("upload_mode" => "preuploaded", "preserve_destination_uploads" => true)
        .to_yaml,
    )
    config = BulkImport::DiscourseMerge::Configuration.new(dir)
    source = {
      "id" => "3",
      "url" => "/uploads/default/original/1X/shared.png",
      "sha1" => "a" * 40,
      "filesize" => "10",
      "secure" => "f",
    }
    dest =
      source.merge(
        "id" => "2",
        "url" => "//bucket.s3.amazonaws.com/production-tenant/original/1X/shared.png",
      )
    @inventory.fetch("source").merge!("uploads" => [source], "optimized_images" => [])
    @inventory.fetch("destination").merge!("uploads" => [dest], "optimized_images" => [])
    target = {
      "bucket" => "bucket",
      "prefix" => "review-tenant",
      "read_prefixes" => {
        "destination" => "s3://bucket/production-tenant",
      },
    }
    store = double(target: target, check!: true)
    snapshot = instance_double(BulkImport::DiscourseMerge::Inventory)
    allow(snapshot).to receive(:connect) do |side, &block|
      pg = instance_double(PG::Connection, exec: nil)
      allow(pg).to receive(:exec).with(/SELECT .* FROM/) { |sql|
        @inventory[side].fetch(sql[/FROM (\w+)/, 1])
      }
      allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each).with(
        pg,
        /\ASELECT /,
      ) do |_, sql, &consume|
        @inventory[side].fetch(sql[/FROM (\w+)/, 1]).each(&consume)
      end
      block.call(pg)
    end
    receipts = BulkImport::DiscourseMerge::PreparedUploads
    dir.join(receipts::FILE).write("old two-sided receipts")
    receipts.open(receipts.path_for(config), readonly: false) do |state|
      state.prepare!(config, store, double(say: nil), workers: 1, inventory: snapshot)
    end
    planner = described_class.new(config, @inventory)
    plan = planner.build
    expect(plan.dig("upload_policy", "retained_ids", "uploads")).to eq("3" => 2)
    expect(plan.dig("upload_policy", "receipt_sha256")).to eq(
      Digest::SHA256.file(receipts.path_for(config)).hexdigest,
    )
    planner.write(plan)
    expect(dir.join("preview.md").read).to include(
      "Retained 1 destination originals",
      "Verified 0 incoming originals",
      "s3://bucket/production-tenant",
      "s3://bucket/review-tenant",
    )
    expect(dir.join(receipts::FILE).read).to eq("old two-sided receipts")
    @inventory["destination"]["uploads"].first[
      "url"
    ] = "//bucket.s3.amazonaws.com/wrong/original/1X/shared.png"
    expect { planner.build }.to raise_error(/Unexpected retained destination URL/)
  end

  it "exports parent placement and explicit category exclusions without losing PMs" do
    FileUtils.rm_r(@configuration.directory.join("mappings"))
    @inventory["source"]["topics"] << { "id" => "20", "archetype" => "private_message" }
    BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).export(
      parent_path: "PYNQ",
      excluded_category_ids: [1],
    )
    planner = described_class.new(@configuration, @inventory)
    plan = planner.build
    expect(plan.fetch("categories").find { |row| row["path"] == ["PYNQ"] }).to include(
      "access" => "public",
    )
    expect(plan.fetch("source_category_actions").first).to include("action" => "exclude")
    expect(plan.fetch("topics").find { |row| row["source_topic_id"] == 20 }).to include(
      "action" => "copy_private_message",
    )
    expect(
      plan
        .fetch("topics")
        .reject { |row| row["source_topic_id"] == 20 }
        .map { |row| row["action"] }
        .uniq,
    ).to eq(["exclude"])
    planner.write(plan)
    expect(@configuration.directory.join("preview.md").read).to include(
      "excluded topic IDs 10, 101",
    )
  end

  it "rejects added tags when incoming tags are disabled" do
    @configuration
      .directory
      .join("merge.yml")
      .write(@configuration.data.merge("import_tags" => false).to_yaml)
    @configuration = BulkImport::DiscourseMerge::Configuration.new(@configuration.directory)
    rewrite { |table| table[0]["add_tags"] = "new-tag" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /conflict with import_tags/,
    )
  end

  it "honors an explicit exclusion for a topic with a missing category" do
    @inventory["source"]["topics"] << {
      "id" => "64",
      "category_id" => "29",
      "archetype" => "regular",
    }
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      csv << [64, 29, "exclude"]
    end

    topic =
      described_class
        .new(@configuration, @inventory)
        .build
        .fetch("topics")
        .find { |row| row["source_topic_id"] == 64 }
    expect(topic).to include("action" => "exclude", "destination_key" => nil)
  end

  it "requires an explicit audience review before routing a topic from a missing category" do
    @inventory["source"]["topics"] << {
      "id" => "64",
      "category_id" => "29",
      "archetype" => "regular",
      "deleted_at" => "2019-04-24 20:39:26 UTC",
    }
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      csv << [64, 29, "include", "Support"]
    end
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /unknown original audience/,
    )
    @configuration
      .directory
      .join("merge.yml")
      .write(@configuration.data.merge("allow_access_changes" => ["Support"]).to_yaml)
    @configuration = BulkImport::DiscourseMerge::Configuration.new(@configuration.directory)
    plan = described_class.new(@configuration, @inventory).build
    orphan = plan.fetch("topics").find { |row| row["source_topic_id"] == 64 }
    expect(orphan).to include("destination_key" => "destination:1", "action" => "copy_discussion")
    expect(orphan.dig("source_state", "deleted_at")).to eq("2019-04-24 20:39:26 UTC")
  end

  it "retains nonregular source archetypes in verification evidence" do
    @inventory["source"]["topics"].first["archetype"] = "banner"
    topic = described_class.new(@configuration, @inventory).build.fetch("topics").first
    expect(topic.fetch("source_archetype")).to eq("banner")
  end

  it "round trips templates deterministically and accounts for every source topic" do
    planner = described_class.new(@configuration, @inventory)
    plan = planner.build
    expect(plan).to eq(planner.build)
    expect(plan.fetch("topics").map { |row| row.fetch("source_topic_id") }).to contain_exactly(
      10,
      101,
    )
    expect(plan.fetch("summary")).to eq("projected_final_categories" => 2, "included_topics" => 2)
    planner.write(plan)
    expect(@configuration.directory.join("preview.md").read).to include("Products")
  end

  it "routes to existing categories, adds tags, and excludes dissolved definitions" do
    rewrite do |table|
      table[0]["action"] = "topics_only"
      table[0]["destination"] = "Support"
      table[0]["add_tags"] = "platform"
    end
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.fetch("topics")[0]).to include(
      "destination_key" => "destination:1",
      "add_tags" => ["platform"],
    )
    expect(plan.fetch("topics")[1].fetch("action")).to eq("exclude")
  end

  it "requires configuration edits to be reloaded before generating a plan" do
    @configuration
      .directory
      .join("merge.yml")
      .write(@configuration.data.merge("namespace" => "changed").to_yaml)
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Configuration changed/,
    )
  end

  it "rejects duplicate target paths with a sheet location" do
    rewrite { |table| table[0]["destination"] = "Support" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /categories.csv, row 2/,
    )
  end

  it "rejects restricted discussions routed to public categories" do
    @inventory.fetch("source").fetch("categories")[0]["read_restricted"] = "t"
    rewrite do |table|
      table[0]["action"] = "topics_only"
      table[0]["destination"] = "Support"
    end
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /restricted content/,
    )
  end

  it "preserves public access when the source has no explicit grant rows" do
    @inventory.fetch("source")["grants"] = []
    plan = described_class.new(@configuration, @inventory).build
    copied = plan.fetch("categories").find { |item| item["operation"] == "retain_source" }
    expect(copied.fetch("grants")).to eq(
      [{ "origin" => "destination", "group_id" => 0, "permission_type" => 1 }],
    )
  end

  it "requires review when restricted content moves to a different private audience" do
    @inventory.fetch("source").fetch("categories")[0]["read_restricted"] = "t"
    @inventory.fetch("destination").fetch("categories")[0]["read_restricted"] = "t"
    @inventory.fetch("source").fetch("grants")[0]["group_id"] = "2"
    @inventory.fetch("destination").fetch("grants")[0]["group_id"] = "3"
    rewrite do |table|
      table[0]["action"] = "topics_only"
      table[0]["destination"] = "Support"
    end
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /changes audience/,
    )
    @configuration.data["allow_access_changes"] = ["Support"]
    expect(
      described_class
        .new(@configuration, @inventory)
        .build
        .fetch("summary")
        .fetch("included_topics"),
    ).to eq(1)
  end

  it "blocks secure uploads until a compatible transfer adapter is available" do
    @inventory.fetch("source")["uploads"] = [{ "id" => "1", "secure" => "t" }]
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Secure source uploads/,
    )
  end

  it "rejects source labels that no longer match the generated identifiers" do
    rewrite { |table| table[0]["source_path"] = "Another category" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /source path does not match/,
    )
  end

  it "refuses verification when the frozen run plan was altered" do
    run = @configuration.directory.join("runs", "fixture")
    run.mkpath
    run.join("plan.json").write("changed")
    BulkImport::DiscourseMerge::Configuration.write(
      @configuration.directory.join("active-run.json"),
      { "status" => "verified", "run_dir" => run.to_s, "plan_sha256" => "0" * 64 },
    )
    expect { BulkImport::DiscourseMerge::Runner.new(@configuration).verify }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Frozen run plan changed/,
    )
  end

  it "rejects case-insensitive collisions before category copying" do
    rewrite { |table| table[0]["destination"] = "support" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /duplicate category path/,
    )
  end

  it "normalizes destination whitespace and ignores empty spreadsheet rows" do
    rewrite { |table| table[0]["destination"] = " Products " }
    CSV.open(@configuration.directory.join("mappings/categories.csv"), "a") do |csv|
      csv << [nil, nil, nil, nil, nil, nil, nil]
    end
    expect(
      described_class
        .new(@configuration, @inventory)
        .build
        .fetch("summary")
        .fetch("included_topics"),
    ).to eq(2)
  end

  it "identifies the sheet row containing an invalid source ID" do
    rewrite { |table| table[0]["source_category_id"] = "wrong" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /categories.csv, row 2: invalid source identifier/,
    )
  end

  it "exports readable access labels and defined live discussion counts" do
    categories = CSV.read(@configuration.directory.join("mappings/categories.csv"), headers: true)
    destinations =
      CSV.read(@configuration.directory.join("mappings/destinations.csv"), headers: true)
    expect(categories[0].to_h).to include("source_access" => "public", "live_discussions" => "1")
    expect(destinations[0]["access"]).to eq("public")
  end

  it "protects customer edits from re-export" do
    expect {
      BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).export
    }.to raise_error(BulkImport::DiscourseMerge::Error, /already exists/)
  end

  it "applies topic overrides while accumulating category tags" do
    rewrite { |table| table[0]["add_tags"] = "origin" }
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      csv << [10, 1, "include", "Support", "help", ""]
    end
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.fetch("topics")[0]).to include(
      "destination_key" => "destination:1",
      "add_tags" => %w[origin help],
    )
  end

  it "rejects duplicate topic instructions" do
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      2.times { csv << [10, 1, "include", "Support", "", ""] }
    end
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /duplicate topic/,
    )
  end

  it "rejects missing category rows instead of silently excluding content" do
    rewrite { |table| table.delete(0) }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /every source category/,
    )
  end

  it "retains PMs with no public category or additional tags" do
    @inventory.fetch("source").fetch("topics") << {
      "id" => "20",
      "category_id" => nil,
      "archetype" => "private_message",
    }
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.fetch("topics").last).to include(
      "action" => "copy_private_message",
      "destination_key" => nil,
      "add_tags" => [],
    )
  end

  it "creates declared new destinations while keeping source category descriptions" do
    CSV.open(@configuration.directory.join("mappings/new_categories.csv"), "a") do |csv|
      csv << ["Help", "New proposal"]
    end
    rewrite { |table| table[0]["topic_destination"] = "Help" }
    plan = described_class.new(@configuration, @inventory).build
    discussion, description = plan.fetch("topics")
    expect(discussion.fetch("destination_key")).not_to eq(description.fetch("destination_key"))
    expect(description.fetch("action")).to eq("keep_category_description")
  end

  it "maps custom groups from workbook selections and preserves automatic group policy",
     workbook: true do
    @inventory["source"]["groups"] = [
      { "id" => "100", "name" => "customers", "automatic" => "f" },
      { "id" => "101", "name" => "designers", "automatic" => "f" },
      { "id" => "102", "name" => "partners", "automatic" => "f" },
      { "id" => "13", "name" => "trust_level_3", "automatic" => "t" },
    ]
    @inventory["destination"]["groups"] = [
      { "id" => "200", "name" => "customers", "automatic" => "f" },
      { "id" => "1", "name" => "admins", "automatic" => "t" },
    ]
    BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).write(
      @configuration.directory.join("mappings/groups.csv"),
      %w[source_group_id action name destination_group_id],
      BulkImport::DiscourseMerge::GroupMapping.defaults(@inventory),
    )
    export_workbook
    edit_workbook do |book|
      put(book, "Group Mapping", "C2", "Merge into existing group")
      put(book, "Group Mapping", "D2", "customers [DG200]")
      put(book, "Group Mapping", "C3", "Rename")
      put(book, "Group Mapping", "E3", "incoming_designers")
      put(book, "Group Mapping", "C4", "Keep separate")
    end
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.fetch("groups")).to contain_exactly(
      {
        "source_group_id" => 100,
        "source_name" => "customers",
        "action" => "reuse",
        "destination_group_id" => 200,
        "name" => "customers",
      },
      {
        "source_group_id" => 101,
        "source_name" => "designers",
        "action" => "copy",
        "destination_group_id" => nil,
        "name" => "incoming_designers",
      },
      {
        "source_group_id" => 102,
        "source_name" => "partners",
        "action" => "copy",
        "destination_group_id" => nil,
        "name" => "partners",
      },
    )
    planner = described_class.new(@configuration, @inventory)
    planner.write(plan)
    expect(@configuration.directory.join("preview.md").read).to include(
      "destination audience",
      "Automatic groups are not customer-mapped",
    )
  end

  it "round trips automatic group matching and records its decision in the preview",
     workbook: true do
    @inventory["source"]["groups"] = [{ "id" => "100", "name" => "ai_users", "automatic" => "f" }]
    @inventory["destination"]["groups"] = [
      { "id" => "200", "name" => "ai_users", "automatic" => "f" },
    ]
    @inventory["source"]["group_memberships"] = [{ "group_id" => "100", "user_id" => "1" }]
    @inventory["source"]["group_user_matches"] = [
      { "source_user_id" => 1, "destination_user_id" => 9 },
    ]
    @inventory["destination"]["group_memberships"] = [{ "group_id" => "200", "user_id" => "9" }]
    BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).write(
      @configuration.directory.join("mappings/groups.csv"),
      %w[source_group_id action name destination_group_id],
      BulkImport::DiscourseMerge::GroupMapping.defaults(@inventory),
    )
    original = described_class.new(@configuration, @inventory).build
    export_workbook
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.except("inputs_sha256")).to eq(original.except("inputs_sha256"))
    expect(plan.fetch("groups").first).to include(
      "action" => "reuse",
      "destination_group_id" => 200,
    )
    described_class.new(@configuration, @inventory).write(plan)
    expect(@configuration.directory.join("preview.md").read).to include(
      "Automatic match:",
      "exact member list",
    )
    @inventory["destination"]["group_memberships"] << { "group_id" => "200", "user_id" => "10" }
    expect(
      described_class.new(@configuration, @inventory).build.fetch("groups").first.fetch("action"),
    ).to eq("copy")
  end

  def exclusion_inventory(dependencies = [])
    @inventory["source"]["groups"] = [{ "id" => "100", "name" => "obsolete", "automatic" => "f" }]
    @inventory["source"]["group_dependencies"] = dependencies
    BulkImport::DiscourseMerge::TemplateExporter.new(@configuration, @inventory).write(
      @configuration.directory.join("mappings/groups.csv"),
      %w[source_group_id action name destination_group_id],
      [{ "source_group_id" => "100", "action" => "exclude" }],
    )
  end

  it "excludes a workbook group while retaining its users and discussions for migration",
     workbook: true do
    exclusion_inventory
    @inventory["destination"]["groups"] = [
      { "id" => "200", "name" => "obsolete", "automatic" => "f" },
    ]
    export_workbook
    plan = described_class.new(@configuration, @inventory).build
    expect(plan.fetch("groups").first).to include(
      "action" => "exclude",
      "destination_group_id" => nil,
    )
    expect(plan.fetch("topics").map { |row| row.fetch("action") }).to eq(
      %w[copy_discussion keep_category_description],
    )
    selection =
      BulkImport::DiscourseMerge::Selection.new(BulkImport::DiscourseMerge::Plan.new(plan))
    sql = selection.sql("group_users", %w[group_id user_id], "SELECT * FROM group_users")
    expect(sql).to include("r.group_id NOT IN (100)")
    described_class.new(@configuration, @inventory).write(plan)
    expect(@configuration.directory.join("preview.md").read).to include(
      "Existing destination groups are untouched",
    )
  end

  it "requires fresh dependency evidence for group exclusions" do
    exclusion_inventory
    @inventory["source"].delete("group_dependencies")
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /fresh inventory/,
    )
  end

  it "blocks excluding a group that controls a copied category" do
    exclusion_inventory
    @inventory["source"]["grants"] << {
      "category_id" => "1",
      "group_id" => "100",
      "permission_type" => "1",
    }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /required by category Products/,
    )
  end

  it "blocks removing an included topic audience and permits dependencies on excluded topics" do
    exclusion_inventory(
      [{ "table_name" => "topic_allowed_groups", "group_id" => "100", "topic_id" => "10" }],
    )
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /topic_allowed_groups/,
    )
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      csv << %w[10 1 exclude]
    end
    expect(
      described_class.new(@configuration, @inventory).build.fetch("groups").first.fetch("action"),
    ).to eq("exclude")
  end

  it "allows exclusions once copied category access explicitly uses destination groups" do
    exclusion_inventory
    @inventory["source"]["grants"] << {
      "category_id" => "1",
      "group_id" => "100",
      "permission_type" => "1",
    }
    @inventory["destination"]["groups"] = [
      { "id" => "0", "name" => "everyone", "automatic" => "t" },
    ]
    @configuration.data["category_access"] = { "Products" => [0] }
    expect(
      described_class.new(@configuration, @inventory).build.fetch("groups").first.fetch("action"),
    ).to eq("exclude")
  end

  it "blocks excluding a group used by included PMs" do
    exclusion_inventory(
      [{ "table_name" => "topic_allowed_groups", "group_id" => "100", "topic_id" => "200" }],
    )
    @inventory["source"]["topics"] << { "id" => "200", "archetype" => "private_message" }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /topic_allowed_groups/,
    )
    @configuration.data["include_private_messages"] = false
    expect(
      described_class.new(@configuration, @inventory).build.fetch("groups").first.fetch("action"),
    ).to eq("exclude")
  end

  it "checks approval dependencies only for categories being copied" do
    exclusion_inventory(
      [
        {
          "table_name" => "category_posting_review_groups",
          "group_id" => "100",
          "category_id" => "1",
        },
      ],
    )
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /category_posting_review_groups/,
    )
    rewrite do |table|
      table[0]["action"] = "topics_only"
      table[0]["destination"] = "Support"
    end
    expect(
      described_class.new(@configuration, @inventory).build.fetch("groups").first.fetch("action"),
    ).to eq("exclude")
  end

  it "blocks exclusion of tag permission groups" do
    exclusion_inventory(
      [{ "table_name" => "tag_group_permissions", "group_id" => "100", "tag_group_id" => "1" }],
    )
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /tag_group_permissions/,
    )
  end

  it "reads older workbooks with default group handling", workbook: true do
    export_workbook
    edit_workbook do |book|
      metadata = JSON.parse(book["Metadata"][1][0].value)
      metadata["version"] = 1
      put(book, "Metadata", "A2", JSON.generate(metadata))
      book.worksheets.delete(book["Group Mapping"])
      book.worksheets.delete(book["Settings"])
    end
    expect(described_class.new(@configuration, @inventory).build.fetch("groups")).to eq([])
  end

  it "keeps source staff roles by default and plans regular accounts when selected",
     workbook: true do
    source = @inventory.fetch("source")
    source["privileged_accounts"] = [
      { "id" => "21", "username" => "source-admin", "admin" => "t", "moderator" => "t" },
      { "id" => "22", "username" => "matched-staff", "admin" => "f", "moderator" => "t" },
    ]
    source["importable_user_ids"] = [21, 22]
    source["account_matches"] = [{ "source_user_id" => 22, "destination_user_id" => 23 }]
    export_workbook
    planner = described_class.new(@configuration, @inventory)
    default_plan = planner.build
    expect(default_plan.dig("policy", "source_staff_roles")).to eq("preserve")
    expect(default_plan.dig("source_findings", "new_staff_account_ids")).to eq([21])

    edit_workbook { |book| put(book, "Settings", "B2", "Import staff as regular users") }
    planner = described_class.new(@configuration, @inventory)
    plan = planner.build
    expect(plan.dig("policy", "source_staff_roles")).to eq("regular_users")
    expect(plan.fetch("inputs_sha256")).not_to eq(default_plan.fetch("inputs_sha256"))
    planner.write(plan)
    preview = @configuration.directory.join("preview.md").read
    expect(preview).to include(
      "New staff accounts: 0.",
      "Accounts imported without source staff roles: 1.",
      "matched; destination flags retained",
    )
  end

  it "keeps the current staff policy for workbook version 2", workbook: true do
    export_workbook
    edit_workbook do |book|
      metadata = JSON.parse(book["Metadata"][1][0].value)
      put(book, "Metadata", "A2", JSON.generate(metadata.merge("version" => 2)))
      book.worksheets.delete(book["Settings"])
    end
    expect(
      described_class.new(@configuration, @inventory).build.dig("policy", "source_staff_roles"),
    ).to eq("preserve")
  end

  it "reports an invalid staff role selection in the workbook", workbook: true do
    export_workbook
    edit_workbook { |book| put(book, "Settings", "B2", "Regular") }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Settings!B2.*choose a listed Source staff roles option/,
    )
  end

  it "rejects a missing group tab in a newly generated workbook", workbook: true do
    export_workbook
    edit_workbook { |book| book.worksheets.delete(book["Group Mapping"]) }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Group Mapping sheet is required/,
    )
  end

  it "exports new-category selections with the same caption as the planned dropdown",
     workbook: true do
    CSV.open(@configuration.directory.join("mappings/new_categories.csv"), "a") do |csv|
      csv << ["Products > Tutorials", "New category"]
    end
    CSV.open(@configuration.directory.join("mappings/topics.csv"), "a") do |csv|
      csv << ["10", "1", "include", "Products > Tutorials"]
    end
    path = export_workbook
    book = RubyXL::Parser.parse(path.to_s)
    expect(book["Topic Exceptions"][1][2].value).to eq("Tutorials [N001]")
    expect(book["Choices"][3][0].formula.expression).to include("VLOOKUP", "New Categories")
    expect(book["Planned Categories"]).not_to eq(nil)
    plan = described_class.new(@configuration, @inventory).build
    paths = plan["categories"].to_h { |row| [row["key"], row["path"]] }
    expect(
      paths[plan["topics"].find { |row| row["source_topic_id"] == 10 }["destination_key"]],
    ).to eq(%w[Products Tutorials])
  end

  def export_workbook
    path = @configuration.directory.join("mappings.xlsx")
    BulkImport::DiscourseMerge::Workbook.new(@configuration, @inventory).export(path)
    path
  end

  def put(book, sheet, address, value)
    row, column = RubyXL::Reference.ref2ind(address)
    cell = book[sheet][row] && book[sheet][row][column]
    if cell
      cell.change_contents(
        value.to_s.start_with?("=") ? nil : value,
        value.to_s.start_with?("=") ? value.delete_prefix("=") : nil,
      )
    else
      book[sheet].add_cell(row, column, value)
    end
  end

  def edit_workbook
    path = @configuration.directory.join("mappings.xlsx")
    book = RubyXL::Parser.parse(path.to_s)
    yield book
    book.write(path.to_s)
  end

  it "round trips workbook decisions through the same planner as CSV", workbook: true do
    rewrite { |table| table[0]["add_tags"] = "platform|second-tag" }
    csv_plan = described_class.new(@configuration, @inventory).build
    export_workbook
    workbook_plan = described_class.new(@configuration, @inventory).build
    expect(workbook_plan.except("inputs_sha256")).to eq(csv_plan.except("inputs_sha256"))
    expect(workbook_plan["inputs_sha256"].keys).to contain_exactly("merge.yml", "mappings.xlsx")
  end

  it "resolves renamed categories and new parents by identifiers after rows move", workbook: true do
    export_workbook
    edit_workbook do |book|
      put(book, "New Categories", "B2", "General")
      put(book, "New Categories", "C2", "Products [S1]")
      put(book, "Category Mapping", "E2", "Renamed")
      put(book, "Category Mapping", "F2", "Old caption [N001]")
      values =
        book["New Categories"]
          .sheet_data
          .rows
          .drop(1)
          .map { |row| row.cells.map { |cell| cell&.raw_value } }
      book["New Categories"].sheet_data.rows.slice!(1, 100)
      values.reverse.each_with_index do |row, index|
        row.each_with_index do |value, column|
          book["New Categories"].add_cell(index + 1, column, value)
        end
      end
    end
    plan = described_class.new(@configuration, @inventory).build
    paths = plan["categories"].to_h { |row| [row["key"], row["path"]] }
    expect(
      paths[plan["topics"].find { |row| row["source_topic_id"] == 10 }["destination_key"]],
    ).to eq(%w[Renamed General])
  end

  it "inherits an excluded category when a workbook exception only adds a note", workbook: true do
    rewrite do |table|
      table[0]["action"] = "exclude"
      table[0]["destination"] = ""
    end
    export_workbook
    edit_workbook do |book|
      put(book, "Topic Exceptions", "A2", "Discussion [T10]")
      put(book, "Topic Exceptions", "E2", "Keep the category decision")
    end

    topics = described_class.new(@configuration, @inventory).build.fetch("topics")
    expect(
      topics.map { |topic| topic.values_at("action", "exclusion_reason", "destination_key") },
    ).to eq(
      [["exclude", "category_excluded", nil], ["exclude", "obsolete_category_description", nil]],
    )
  end

  it "matches retained category forms by name and content across different IDs" do
    @inventory["source"]["category_form_templates"] = [
      {
        "category_id" => "1",
        "form_template_id" => "3",
        "name" => "Intake",
        "template" => "fields",
      },
    ]
    forms =
      @inventory["destination"]["form_templates"] = [
        { "id" => "3", "name" => "Other", "template" => "fields" },
        { "id" => "4", "name" => "Intake", "template" => "fields" },
      ]

    planner = described_class.new(@configuration, @inventory)
    expect(planner.build.fetch("form_templates")).to eq("3" => 4)
    forms.last["template"] = "different"
    expect { planner.build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Source category 1.*Intake/,
    )
  end

  it "routes a discussion exception and inherits category tags", workbook: true do
    rewrite { |table| table[0]["add_tags"] = "platform" }
    export_workbook
    edit_workbook do |book|
      position = book["Topic Exceptions"].sheet_data.size
      [
        "Discussion [T10]",
        "Move discussion",
        "Support [D1]",
        "extra",
        "",
      ].each_with_index do |value, column|
        book["Topic Exceptions"].add_cell(position, column, value)
      end
    end
    plan = described_class.new(@configuration, @inventory).build
    expect(plan["topics"].find { |row| row["source_topic_id"] == 10 }).to include(
      "destination_key" => "destination:1",
      "add_tags" => %w[platform extra],
    )
  end

  it "rejects circular parents selected in the workbook", workbook: true do
    export_workbook
    edit_workbook { |book| put(book, "Category Mapping", "D2", "Products [S1]") }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /mappings.xlsx: Category Mapping, row 2: .*cycle/,
    )
  end

  it "rejects formulas pasted into customer mapping cells", workbook: true do
    export_workbook
    edit_workbook { |book| put(book, "Category Mapping", "E2", "=1+1") }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /formulas are not allowed/,
    )
  end

  it "rejects macros and XML entity declarations in returned workbooks", workbook: true do
    path = export_workbook
    original = path.binread
    {
      "xl/vbaProject.bin" => "macro payload",
      "xl/unsafe.xml" => '<!DOCTYPE workbook [<!ENTITY unsafe "value">]><workbook/>',
    }.each do |entry, contents|
      path.binwrite(original)
      Zip::File.open(path.to_s) do |zip|
        zip.get_output_stream(entry) { |stream| stream.write(contents) }
      end
      expect { described_class.new(@configuration, @inventory).build }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /Macro-enabled|XML entities/,
      )
    end
  end

  it "rejects targets for empty new category slots", workbook: true do
    export_workbook
    edit_workbook { |book| put(book, "Category Mapping", "F2", "New category [N099]") }
    expect { described_class.new(@configuration, @inventory).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /empty or omitted category/,
    )
  end

  it "binds a workbook to its source and destination project", workbook: true do
    export_workbook
    other = Marshal.load(Marshal.dump(@inventory))
    other["source"]["database"] = "another_source"
    expect { described_class.new(@configuration, other).build }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      %r{another source/destination project},
    )
  end

  it "includes workbook edits in the reviewed input fingerprint", workbook: true do
    export_workbook
    before = described_class.new(@configuration, @inventory).build
    edit_workbook { |book| put(book, "Category Mapping", "H2", "Customer approved") }
    after = described_class.new(@configuration, @inventory).build
    expect(after["inputs_sha256"]).not_to eq(before["inputs_sha256"])
  end

  it "exports a discussion whose original category has been removed", workbook: true do
    @inventory["source"]["topics"].first["category_id"] = "999"
    book = RubyXL::Parser.parse(export_workbook.to_s)
    expect(book["Topic Catalog"][1][1].value).to eq("Missing source category (999)")
  end

  it "keeps private message titles out of the workbook", workbook: true do
    @inventory["source"]["topics"] << {
      "id" => "200",
      "archetype" => "private_message",
      "title" => "Confidential message",
    }
    @inventory["source"]["topics"][0]["title"] = '=HYPERLINK("https://example.com")'
    path = export_workbook
    book = RubyXL::Parser.parse(path.to_s)
    values = book["Topic Catalog"].sheet_data.rows.flat_map { |row| row.cells.compact.map(&:value) }
    expect(values.join).not_to include("Confidential message")
    expect(book["Topic Catalog"][1][0].formula).to eq(nil)
    expect(book["Topic Catalog"][1][0].value).to include("HYPERLINK")
  end
end

RSpec.describe BulkImport::DiscourseMerge::References do
  it "repairs links, quotes and mentions without rewriting code examples" do
    references =
      described_class.new(
        source_host: "source.example",
        destination_host: "destination.example",
        topics: {
          1 => 99,
        },
        categories: {
          1 => 88,
        },
        usernames: {
          "old" => "renamed",
        },
      )
    expect(
      references.rewrite("https://source.example/t/1/2 @old `https://source.example/t/1`"),
    ).to eq("https://destination.example/t/99/2 @renamed `https://source.example/t/1`")
    expect(references.rewrite('[quote="old, post:1, topic:1"]')).to eq(
      '[quote="renamed, post:1, topic:99"]',
    )
  end

  it "respects non-TLS destination origins and source ports" do
    references =
      described_class.new(
        source_host: "localhost:8080",
        destination_host: "localhost:8081",
        destination_base_url: "http://localhost:8081",
        topics: {
          1 => 2,
        },
        categories: {
        },
      )
    expect(references.rewrite("http://localhost:8080/t/1")).to eq("http://localhost:8081/t/2")
  end

  it "rejects an unmapped typed reference rather than guessing an ID" do
    references =
      described_class.new(
        source_host: "source.example",
        destination_host: "destination.example",
        topics: {
        },
        categories: {
        },
      )
    expect { references.metadata({ "topic_id" => 4 }, { topics: {} }) }.to raise_error(
      BulkImport::DiscourseMerge::Error,
      /Unmapped metadata reference/,
    )
  end
end

RSpec.describe BulkImport::DiscourseMerge::Environment do
  it "distinguishes active workers from supervisors and operator shells" do
    expect(
      described_class.workers_running?("runsv runsv unicorn\nbash bash -lc sv stop unicorn\n"),
    ).to eq(false)
    expect(
      described_class.workers_running?("ruby unicorn worker[0] -c config/unicorn.conf.rb\n"),
    ).to eq(true)
    expect(described_class.workers_running?("ruby sidekiq 7.0 application [busy]\n")).to eq(true)
  end
end
