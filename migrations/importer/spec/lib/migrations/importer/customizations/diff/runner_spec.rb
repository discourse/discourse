# frozen_string_literal: true

require "pg"
require "stringio"

# Needs a local PostgreSQL on the unix socket; it creates and drops its own
# databases and is skipped when the server isn't reachable.
RSpec.describe Migrations::Importer::Customizations::Diff::Runner do
  let(:host) { "/var/run/postgresql" }
  let(:suffix) { "#{Process.pid}_#{rand(1_000_000)}" }
  let(:before_name) { "customizations_diff_before_#{suffix}" }
  let(:after_name) { "customizations_diff_after_#{suffix}" }
  let(:warnings) { StringIO.new }

  def connect(dbname)
    PG.connect(dbname:, host:)
  end

  def create_database(name, sql)
    @admin.exec("CREATE DATABASE #{name}")
    conn = connect(name)
    conn.exec(<<~SQL)
      CREATE TABLE site_settings (
        id integer PRIMARY KEY, name text, data_type integer, value text, updated_at text
      );
      CREATE TABLE uploads (
        id integer PRIMARY KEY, url text, original_filename text, filesize integer, sha1 text
      );
      CREATE TABLE notes (body text);
      CREATE TABLE badges (id integer PRIMARY KEY, name text);
      INSERT INTO badges VALUES (1, 'Welcome');
      CREATE TABLE posts (id integer PRIMARY KEY, raw text);
      INSERT INTO uploads VALUES (5, '/uploads/logo.png', 'logo.png', 10, 'abc');
      INSERT INTO site_settings VALUES
        (1, 'title', 1, 'Old', 't1'),
        (2, 'vapid_public_key', 1, 'one', 't1');
      INSERT INTO notes VALUES ('kept');
      INSERT INTO posts VALUES (1, 'hello');
    SQL
    conn.exec(sql) if sql.present?
    conn.close
  end

  around do |example|
    begin
      @admin = connect("postgres")
    rescue PG::Error => e
      skip "PostgreSQL not reachable: #{e.message}"
    end

    begin
      create_database(before_name, "")
      create_database(after_name, <<~SQL)
        UPDATE site_settings SET value = 'New', updated_at = 't2' WHERE id = 1;
        UPDATE site_settings SET value = 'two' WHERE id = 2;
        INSERT INTO site_settings VALUES
          (3, 'logo', 18, '5', 't2'),
          (4, 'github_client_secret', 1, 'abcdef', 't2');
        INSERT INTO notes VALUES ('new note');
        INSERT INTO posts VALUES (2, 'content is skipped');
      SQL
      example.run
    ensure
      [before_name, after_name].each { |name| @admin.exec("DROP DATABASE IF EXISTS #{name}") }
      @admin.close
    end
  end

  def run_diff(**options)
    described_class.new(
      before: "dbname=#{before_name} host=#{host}",
      after: "dbname=#{after_name} host=#{host}",
      redactor: Migrations::Importer::Customizations::Diff::Redactor.new,
      warnings:,
      **options,
    ).run
  end

  it "reports changed tables in the format `plan` reads" do
    report = JSON.parse(JSON.generate(run_diff.report))

    expect(report.keys).to eq(
      %w[only_in_before only_in_after skipped identical too_large schema_mismatch tables uploads],
    )
    expect(report["identical"]).to eq(["badges"])
    expect(report["skipped"]).to eq(
      "posts" => {
        "before" => 1,
        "after" => 2,
      },
      "uploads" => {
        "before" => 1,
        "after" => 1,
      },
    )

    settings = report["tables"]["site_settings"]
    expect(settings["key"]).to eq(["id"])
    expect(settings["where"]).to eq("name NOT LIKE 'vapid_%'")
    expect(settings["changed"].map { |c| c["after"]["name"] }).to eq(["title"])
    expect(settings["changed"].first["diffs"]).to eq(
      "value" => %w[Old New],
      "updated_at" => %w[t1 t2],
    )
    added = settings["added"].index_by { |row| row["name"] }
    expect(added["github_client_secret"]["value"]).to match(/\A\[redacted:\h{8}\]\z/)

    expect(report["tables"]["notes"]["key"]).to eq([])
    expect(report["tables"]["notes"]["added"]).to eq([{ "body" => "new note" }])
    expect(report["uploads"]).to eq(
      "5" => {
        "id" => "5",
        "url" => "/uploads/logo.png",
        "original_filename" => "logo.png",
        "filesize" => "10",
        "sha1" => "abc",
      },
    )
  end

  it "honours table selection, row filters and the row limit" do
    report =
      run_diff(
        only: %w[site_settings posts],
        row_filters: {
          "site_settings" => "id >= 2",
        },
        max_rows: 3,
      ).report

    expect(report[:skipped]).to be_empty
    expect(report[:tables].keys).to eq(%w[posts site_settings])
    expect(report[:tables]["site_settings"][:changed].map { |c| c[:key] }).to eq([["2"]])

    expect(run_diff(max_rows: 2).report[:too_large]).to include(
      "site_settings" => {
        before: 1,
        after: 3,
      },
    )
  end

  it "prints a readable summary" do
    output = StringIO.new
    Migrations::Importer::Customizations::Diff::Printer.new(run_diff, output:).print

    expect(output.string).to include("Tables compared: 3, identical: 1, differing: 2")
    expect(output.string).to include("  ~ 1 (title)", "value: \"Old\" => \"New\"")
    expect(output.string).to include("5: logo.png (10 bytes) /uploads/logo.png")
    expect(output.string).not_to include("abcdef")
  end
end
