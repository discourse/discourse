# frozen_string_literal: true

require "tmpdir"
require "stringio"
require_relative "../../../../script/bulk_import/discourse_merger/support"
require_relative "../../../../script/bulk_import/discourse_merger/runner"
require_relative "../../../../script/bulk_import/discourse_merger/initializer"

RSpec.describe BulkImport::DiscourseMerge::Media do
  it "qualifies relative and protocol-relative URLs against the original origin" do
    expect(described_class.remote_url("/uploads/a.png", "https://pynq.example")).to eq(
      "https://pynq.example/uploads/a.png",
    )
    expect(described_class.remote_url("//cdn.example/a.png", "https://pynq.example")).to eq(
      "https://cdn.example/a.png",
    )
    expect(described_class.remote_url("https://s3.example/a.png", "https://pynq.example")).to eq(
      "https://s3.example/a.png",
    )
  end

  it "rejects URLs that cannot be retained as public HTTP media" do
    %w[javascript:alert(1) file:///tmp/a https://user:password@example.com/a].each do |url|
      expect { described_class.remote_url(url, "https://pynq.example") }.to raise_error(
        BulkImport::DiscourseMerge::Error,
      )
    end
  end

  it "requires consistent size metadata before reusing a SHA-1" do
    source = { "id" => "1", "sha1" => "abc", "filesize" => "12" }
    expect {
      described_class.validate_reuse!(source, source.merge("filesize" => 12))
    }.not_to raise_error
    expect {
      described_class.validate_reuse!(source, source.merge("filesize" => 13))
    }.to raise_error(BulkImport::DiscourseMerge::Error, /inconsistent size/)
  end
end

RSpec.describe BulkImport::DiscourseMerge::References do
  def references(mode = "preserve_remote", **options)
    described_class.new(
      source_host: "pynq.example",
      source_base_url: "https://pynq.example",
      destination_host: "amd.example",
      topics: {
        1 => 101,
      },
      categories: {
        2 => 102,
      },
      usernames: {
        "old" => "new",
      },
      group_names: {
        "source" => "target",
      },
      upload_mode: mode,
      **options,
    )
  end

  it "keeps remote originals, thumbnails, avatars and short upload references while remapping links" do
    text =
      "![image](/uploads/default/original/a.png) https://cdn.example/optimized/b.png upload://abc.png /user_avatar/pynq.example/old/120/1.png /t/1 /c/2 /u/old /g/source"
    expect(references.rewrite(text)).to eq(
      "![image](https://pynq.example/uploads/default/original/a.png) https://cdn.example/optimized/b.png upload://abc.png https://pynq.example/user_avatar/pynq.example/old/120/1.png https://amd.example/t/101 https://amd.example/c/102 https://amd.example/u/new https://amd.example/g/target",
    )
  end

  it "preserves absolute PYNQ media and handles srcset entries in cooked HTML" do
    html =
      '<img src="https://pynq.example/uploads/a.png" srcset="/uploads/a.png 1x, /uploads/b.png 2x">'
    expect(references.rewrite(html, cooked: true)).to eq(
      '<img src="https://pynq.example/uploads/a.png" srcset="https://pynq.example/uploads/a.png 1x, https://pynq.example/uploads/b.png 2x">',
    )
  end

  it "routes reused originals and optimized images to the destination's retained metadata" do
    urls = {
      "/uploads/a.png" => "https://amd.example/uploads/reused.png",
      "https://cdn.example/b.png" => "https://amd.example/uploads/reused-thumb.png",
    }
    expect(
      references(media_urls: urls).rewrite("![](/uploads/a.png) ![](https://cdn.example/b.png)"),
    ).to eq(
      "![](https://amd.example/uploads/reused.png) ![](https://amd.example/uploads/reused-thumb.png)",
    )
  end

  it "retains the existing copy-mode media rewrite" do
    expect(references("copy").rewrite("https://pynq.example/uploads/a.png")).to eq(
      "https://amd.example/uploads/a.png",
    )
  end

  it "does not replace a reused path embedded in another host's URL or filename" do
    urls = { "/uploads/a.png" => "https://amd.example/uploads/reused.png" }
    expect(
      references(media_urls: urls).rewrite(
        "https://other.example/uploads/a.png /uploads/a.png.backup",
      ),
    ).to eq("https://other.example/uploads/a.png https://pynq.example/uploads/a.png.backup")
  end

  it "keeps a query suffix and recognizes reused URLs next to Markdown delimiters" do
    urls = {
      "/uploads/a.png" => "https://amd.example/uploads/a.png",
      "//cdn.example/b.png" => "https://amd.example/uploads/b.png",
    }
    expect(
      references(media_urls: urls).rewrite("[A](/uploads/a.png?x=1#top),[B](//cdn.example/b.png)"),
    ).to eq("[A](https://amd.example/uploads/a.png?x=1#top),[B](https://amd.example/uploads/b.png)")
  end
end

RSpec.describe BulkImport::DiscourseMerge::Configuration do
  def config(directory, **values)
    data = {
      "source" => {
        "dbname" => "source",
      },
      "destination" => {
        "dbname" => "destination",
      },
      "source_url" => "https://pynq.example",
      "destination_url" => "https://amd.example",
    }.merge(values.transform_keys(&:to_s))
    File.write(File.join(directory, "merge.yml"), data.to_yaml)
    described_class.new(directory)
  end

  it "accepts remote mode without any local upload directories" do
    Dir.mktmpdir do |directory|
      configuration = config(directory, upload_mode: "preserve_remote")
      expect(configuration.preserve_remote?).to eq(true)
      expect {
        BulkImport::DiscourseMerge::Runner.new(configuration).verify_source_files({}, {})
      }.not_to raise_error
    end
  end

  it "keeps copy as the default and requires its upload paths" do
    Dir.mktmpdir do |directory|
      expect { config(directory) }.to raise_error(KeyError, /source_upload_root/)
      expect(
        config(
          directory,
          source_upload_root: "/source",
          destination_upload_root: "/destination",
        ).upload_mode,
      ).to eq("copy")
      expect { config(directory, upload_mode: "unknown") }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /upload_mode/,
      )
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Environment do
  it "detects Pitchfork masters and workers, while ignoring supervisor commands" do
    expect(
      described_class.workers_running?("ruby pitchfork master -c config/pitchfork.conf.rb\n"),
    ).to eq(true)
    expect(described_class.workers_running?("pitchfork pitchfork worker[0]\n")).to eq(true)
    expect(
      described_class.workers_running?("runsv runsv pitchfork\nbash bash -lc sv stop pitchfork\n"),
    ).to eq(false)
  end
end

RSpec.describe BulkImport::DiscourseMerge::Runner do
  it "retains copy-mode size and hash validation against real local original bytes" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      root.join("original").mkpath
      file = root.join("original/test.png")
      file.write("original bytes")
      configuration =
        instance_double(
          BulkImport::DiscourseMerge::Configuration,
          directory: root,
          preserve_remote?: false,
        )
      runner = described_class.new(configuration)
      plan = {
        "upload_policy" => {
          "source_upload_root" => directory,
          "source_hash_discrepancy_ids" => [],
        },
      }
      upload = {
        "id" => "1",
        "url" => "/uploads/default/original/test.png",
        "filesize" => file.size.to_s,
        "sha1" => Digest::SHA1.file(file).hexdigest,
      }
      inventory = { "source" => { "uploads" => [upload] } }
      expect { runner.verify_source_files(plan, inventory) }.not_to raise_error
      file.write("modified bytes")
      expect { runner.verify_source_files(plan, inventory) }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /recorded hash/,
      )
      file.write("short")
      expect { runner.verify_source_files(plan, inventory) }.to raise_error(
        BulkImport::DiscourseMerge::Error,
        /Wrong upload size/,
      )
    end
  end
end

RSpec.describe BulkImport::DiscourseMerge::Initializer do
  it "generates remote-policy CSV decisions with a parent and explicit exclusions" do
    inventory = {
      "source" => {
        "categories" => [
          { "id" => "1", "name" => "Support", "parent_category_id" => nil },
          { "id" => "2", "name" => "Staff", "parent_category_id" => nil },
        ],
        "topics" => [],
      },
      "destination" => {
        "categories" => [],
      },
    }
    capture =
      instance_double(
        BulkImport::DiscourseMerge::Inventory,
        capture: inventory,
        source_categories:
          inventory.dig("source", "categories").index_by { |row| row.fetch("id").to_i },
      )
    allow(BulkImport::DiscourseMerge::Inventory).to receive(:new).and_return(capture)
    runner = instance_double(BulkImport::DiscourseMerge::Runner)
    allow(BulkImport::DiscourseMerge::Runner).to receive(:new).and_return(runner)
    allow(runner).to receive(:preflight).with(setup_only: true)
    answers = [
      "",
      "pynq_forum",
      "",
      "https://pynq.example",
      "https://amd.example",
      "pynq",
      "preserve_remote",
      "yes",
      "no",
      "PYNQ",
      "2",
    ]
    Dir.mktmpdir do |directory|
      output = StringIO.new
      described_class.new(
        directory,
        input: StringIO.new(answers.join("\n") + "\n"),
        output: output,
      ).run
      expect(output.string).to match(
        /1  Support.*2  Staff.*Explicitly exclude source category IDs/m,
      )
      expect(output.string).not_to include("password environment variable")
      configuration = BulkImport::DiscourseMerge::Configuration.new(directory)
      expect(configuration.connection("source")).to eq(
        dbname: "pynq_forum",
        host: "/var/run/postgresql",
        port: 5432,
        user: "discourse",
      )
      expect(configuration.connection("destination").fetch(:dbname)).to eq("discourse")
      expect(configuration.preserve_remote?).to eq(true)
      expect(configuration.data.fetch("import_tags")).to eq(false)
      mappings = CSV.read(File.join(directory, "mappings/categories.csv"), headers: true)
      expect(mappings[0]["destination"]).to eq("PYNQ > Support")
      expect(mappings[1]["action"]).to eq("exclude")
      expect(File.exist?(File.join(directory, "active-run.json"))).to eq(false)
    end
  end

  it "keeps custom PostgreSQL connections and gives another attempt after a forum URL" do
    answers = [
      "custom",
      "prepared_source",
      "https://source.example",
      "database.example",
      "5433",
      "reader",
      "SOURCE_DB_PASSWORD",
      "",
      "",
      "",
      "",
      "",
      "https://source.example",
      "https://destination.example",
      "",
      "preserve_remote",
      "",
      "",
      "4",
    ]
    output = StringIO.new
    initializer =
      described_class.new("/unused", input: StringIO.new(answers.join("\n") + "\n"), output: output)
    configuration = initializer.collect_configuration
    expect(output.string).to include("The forum URL comes later")
    expect(configuration.fetch("source")).to eq(
      "dbname" => "prepared_source",
      "host" => "database.example",
      "port" => 5433,
      "user" => "reader",
      "password_env" => "SOURCE_DB_PASSWORD",
    )
    expect(configuration).to include(
      "source_url" => "https://source.example",
      "max_category_depth" => 4,
    )
  end

  it "resumes after setup failure or interrupted prompts and preserves edited CSVs and workbooks" do
    Dir.mktmpdir do |directory|
      project = Pathname.new(directory)
      configuration = {
        "source" => {
          "dbname" => "incoming",
        },
        "destination" => {
          "dbname" => "destination",
        },
        "source_url" => "https://source.example",
        "destination_url" => "https://destination.example",
        "upload_mode" => "preserve_remote",
      }.to_yaml
      project.join("merge.yml").write(configuration)
      runner = instance_double(BulkImport::DiscourseMerge::Runner)
      allow(BulkImport::DiscourseMerge::Runner).to receive(:new).and_return(runner)
      allow(runner).to receive(:preflight).with(setup_only: true).and_raise(
        BulkImport::DiscourseMerge::Error,
        "Cannot read stopped status",
      )
      output = StringIO.new
      expect {
        described_class.new(project, input: StringIO.new, output: output).run
      }.to raise_error(BulkImport::DiscourseMerge::Error, /Cannot read stopped status/)
      expect(output.string).to include("Using #{project.join("merge.yml")}")
      expect(project.join("mappings")).not_to exist

      allow(runner).to receive(:preflight).with(setup_only: true)
      inventory = instance_double(BulkImport::DiscourseMerge::Inventory, source_categories: {})
      allow(BulkImport::DiscourseMerge::Inventory).to receive(:new).and_return(inventory)
      expect {
        described_class.new(project, input: StringIO.new, output: StringIO.new).run
      }.to raise_error(BulkImport::DiscourseMerge::Error, /Setup interrupted/)
      expect(project.join("mappings")).not_to exist

      project.join("mappings").mkdir
      project.join("mappings/categories.csv").write("edited CSV")
      project.join("mappings.xlsx").write("edited workbook")
      described_class.new(project, input: StringIO.new, output: StringIO.new).run
      expect(project.join("merge.yml").read).to eq(configuration)
      expect(project.join("mappings/categories.csv").read).to eq("edited CSV")
      expect(project.join("mappings.xlsx").read).to eq("edited workbook")
    end
  end
end
