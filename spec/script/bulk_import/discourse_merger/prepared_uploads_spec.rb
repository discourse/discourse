# frozen_string_literal: true

require "tmpdir"
require "pg"
require "sqlite3"
require_relative "../../../../script/bulk_import/native_upload_store"
require_relative "../../../../script/bulk_import/discourse_merger/verifier"
require_relative "../../../../script/bulk_import/discourse_merger/preuploaded_media"

RSpec.describe BulkImport::DiscourseMerge::PreparedUploads do
  let(:state_path) { @directory.join(described_class::FILE) }
  let(:configuration) do
    Struct.new(:data, :directory).new(
      {
        "source_url" => "https://incoming.example",
        "destination_url" => "https://hosted.example",
        "source_upload_root" => @directory.join("source").to_s,
        "destination_upload_root" => @directory.join("destination").to_s,
      },
      @directory,
    )
  end
  let(:rows) { %w[source destination].index_with { { "uploads" => [], "optimized_images" => [] } } }
  let(:target) do
    {
      "bucket" => "hosted",
      "prefix" => "uploads/final",
      "origin" => "//hosted.s3.example",
      "cdn" => "https://cdn.example",
    }
  end
  let(:bytes) { {} }
  let(:access) { {} }
  let(:store) { instance_double(BulkImport::NativeUploadStore, target: target, check!: true) }
  let(:progress) { instance_double(BulkImport::DiscourseMerge::Progress, say: nil) }
  let(:inventory) { instance_double(BulkImport::DiscourseMerge::Inventory) }
  let(:object_info) { Struct.new(:content_length, :etag) }
  let(:plan) { { "policy" => configuration.data, "upload_policy" => {} } }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = Pathname(directory)
      example.run
    end
  end

  before do
    allow(inventory).to receive(:connect) do |side, &block|
      pg = instance_double(PG::Connection, exec: nil)
      allow(pg).to receive(:exec).with(/SELECT .* FROM/) { |sql|
        rows.fetch(side).fetch(sql[/FROM (\w+)/, 1])
      }
      allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each_batch).with(
        pg,
        /\ASELECT /,
      ) do |_, sql, &consume|
        rows.fetch(side).fetch(sql[/FROM (\w+)/, 1]).each_slice(1000, &consume)
      end
      block.call(pg)
    end
    allow(store).to receive(:object) { |path| path }
    allow(store).to receive(:location) { |path| "//hosted.s3.example/uploads/final/#{path}" }
    allow(store).to receive(:head) do |path|
      object_info.new(bytes[path].bytesize, Digest::MD5.hexdigest(bytes[path])) if bytes.key?(path)
    end
    allow(store).to receive(:digests) { |path|
      [Digest::SHA1.hexdigest(bytes.fetch(path)), Digest::SHA256.hexdigest(bytes.fetch(path))]
    }
    allow(store).to receive(:check_access!) { |path, secure|
      raise "wrong visibility" unless access.fetch(path) == secure
    }
    allow(store).to receive(:create) do |path, file, _, secure, _|
      raise "attempted overwrite" if bytes.key?(path)
      bytes[path] = file.binread
      access[path] = secure
      store.head(path)
    end
  end

  def original(side, id, content, hosted: false, secure: false)
    digest = Digest::SHA1.hexdigest(content)
    identity = secure ? "a" * 40 : digest
    path = "original/1X/#{identity}.png"
    rows.fetch(side).fetch("uploads") << {
      "id" => id.to_s,
      "url" => hosted ? store.location(path) : "/uploads/default/#{path}",
      "sha1" => identity,
      "filesize" => content.bytesize.to_s,
      "secure" => secure ? "t" : "f",
      "original_sha1" => secure ? digest : nil,
      "original_filename" => "attachment.png",
      "extension" => "png",
    }
    if hosted
      bytes[path] = content
      access[path] = secure
    else
      file = @directory.join(side, path)
      file.dirname.mkpath
      file.binwrite(content)
    end
    path
  end

  def prepare
    described_class.open(state_path, readonly: false) do |state|
      state.prepare!(configuration, store, progress, workers: 2, inventory: inventory)
    end
  end

  def read(&block)
    described_class.open(state_path, &block)
  end

  context "when destination uploads are retained" do
    let(:production) { "//hosted.s3.dualstack.us-west-2.amazonaws.com/production-tenant" }

    before do
      configuration.data["preserve_destination_uploads"] = true
      target["read_prefixes"] = { "destination" => "s3://hosted/production-tenant" }
    end

    def shared_original
      path = original("source", 6, "shared")
      rows["destination"]["uploads"] << rows["source"]["uploads"].last.merge(
        "id" => "97",
        "url" => "#{production}/#{path}",
      )
      path
    end

    def variant(id, width)
      {
        "id" => id.to_s,
        "upload_id" => "6",
        "width" => width.to_s,
        "height" => "10",
        "extension" => ".png",
        "version" => "2",
        "sha1" => Digest::SHA1.hexdigest("thumbnail"),
        "filesize" => "9",
        "url" => "/uploads/default/optimized/1X/shared_2_#{width}x10.png",
      }
    end

    it "checks and prepares only incoming keys, and validates retained IDs and URLs offline" do
      allow(store).to receive(:read_backup)
      shared = shared_original
      match = variant(12, 10)
      extra = variant(13, 20)
      rows["source"]["optimized_images"].concat([match, extra])
      rows["destination"]["optimized_images"] << match.merge(
        "id" => "98",
        "upload_id" => "97",
        "url" => "#{production}/optimized/1X/old.png",
      )
      incoming = original("source", 8, "incoming")
      image_key = extra["url"].delete_prefix("/uploads/default/")
      stub_const("OptimizedImage", Class.new) unless defined?(OptimizedImage)
      allow(OptimizedImage).to receive(:resize) do |file, output, _, _, **_|
        expect(File.read(file)).to eq("shared")
        File.binwrite(output, "regenerated")
      end
      SQLite3::Database.new(":memory:") do |db|
        counts =
          described_class.new(db).prepare!(
            configuration,
            store,
            progress,
            workers: 2,
            inventory: inventory,
            check_only: true,
          )
        expect(counts).to eq("missing" => 2)
        expect(bytes).to be_empty
        expect(db.get_first_value("SELECT value FROM metadata WHERE name='complete'")).to be_nil
      end
      prepare
      prepare
      expect(bytes).to eq(incoming => "incoming", image_key => "regenerated")
      expect(store).not_to have_received(:object).with(shared)
      expect(store).not_to have_received(:object).with(
        match["url"].delete_prefix("/uploads/default/"),
      )
      read do |state|
        state.validate!(
          rows,
          origins: configuration.data.values_at("source_url", "destination_url"),
        )
        expect(state.receipt("source", "uploads", 6)).to be_nil
        expect(state.receipt("destination", "uploads", 97)).to be_nil
        expect(state.retained.summary).to include(
          "reused_originals" => 1,
          "reused_thumbnails" => 1,
          "additional_thumbnails" => 1,
          "staged" => {
            "uploads" => 1,
            "optimized_images" => 1,
          },
        )
        plan["upload_policy"].merge!(
          "preserve_destination_uploads" => true,
          "retained_ids" =>
            state.retained.reuse.transform_values { |ids| ids.transform_keys(&:to_s) },
        )
        media = BulkImport::DiscourseMerge::PreuploadedMedia.new(state, plan)
        expect(media.update_destination!).to be_nil
        expect(media.source_result("optimized_images", 12, 98)).to be_nil
        expect { media.source_result("optimized_images", 12, 99) }.to raise_error(
          /destination ID changed/,
        )
        map = {}
        media.map_urls(map, "source", match["url"], nil, "https:#{production}/optimized/1X/old.png")
        expect(map[match["url"]]).to eq("https:#{production}/optimized/1X/old.png")
        rows["destination"]["optimized_images"].first[
          "url"
        ] = "#{production}/optimized/1X/drift.png"
        expect {
          state.validate!(
            rows,
            origins: configuration.data.values_at("source_url", "destination_url"),
          )
        }.to raise_error(/inventory changed/)
      end
      expect(store).not_to have_received(:read_backup)
    end

    it "reuses an absent archive duplicate and rejects changed incoming bytes before target access" do
      shared = shared_original
      @directory.join("source", shared).delete
      incoming = original("source", 8, "incoming")
      prepare
      @directory.join("source", incoming).binwrite("tampered")
      expect { prepare }.to raise_error(/differs from recorded digest/)
      expect(store).to have_received(:check!).once
      expect(bytes).to eq(incoming => "incoming")
    end

    it "pins an approved discrepancy to its exact source bytes, target and SQL identity" do
      key = original("source", 6815, "wrong")
      file = @directory.join("source", key)
      file.binwrite("right")
      entry = {
        "side" => "source",
        "id" => 6815,
        "relative_key" => key,
        "size" => 5,
        "recorded_sha1" => Digest::SHA1.hexdigest("wrong"),
        "sha256" => Digest::SHA256.hexdigest("right"),
      }
      manifest = {
        "status" => "approved",
        "review_target" => "s3://hosted/uploads/final",
        "destination_read_prefix" => "s3://hosted/production-tenant",
        "entries" => [entry],
      }
      approval = @directory.join("approved-originals.json")
      approval.write(manifest.to_json)
      prepare
      expect(bytes.fetch(key)).to eq("right")
      file.binwrite("wrong")
      expect { prepare }.to raise_error(/differs from recorded digest/)
      file.binwrite("right")
      approval.write(manifest.merge("review_target" => "s3://hosted/other").to_json)
      expect { prepare }.to raise_error(/do not match the configured S3 target/)
      approval.write(manifest.to_json)
      rows["source"]["uploads"].first["sha1"] = "f" * 40
      expect { prepare }.to raise_error(/Approved original no longer matches/)
      expect(store).to have_received(:check!).once
    end

    it "blocks a reused thumbnail with changed byte metadata" do
      shared_original
      image = variant(12, 10)
      rows["source"]["optimized_images"] << image
      rows["destination"]["optimized_images"] << image.merge(
        "id" => "98",
        "upload_id" => "97",
        "sha1" => "a" * 40,
        "url" => "#{production}/optimized/1X/old.png",
      )
      expect { prepare }.to raise_error(/Conflicting retained thumbnail metadata/)
      expect(store).not_to have_received(:check!)
    end

    it "rejects unexpected destination origins, keys and protected records before any S3 call" do
      shared = shared_original
      dest = rows["destination"]["uploads"].first
      [
        "https://cdn.example/production-tenant/#{shared}",
        "#{production}-other/#{shared}",
        "#{production}/more/#{shared}",
        "#{production}/#{shared}?other",
        "#{production.sub("hosted.", "unexpected.")}/#{shared}",
        "/uploads/default/#{shared}",
      ].each do |url|
        dest["url"] = url
        expect { prepare }.to raise_error(/Unexpected retained destination URL/)
      end
      dest["url"] = "#{production}/#{shared}"
      dest["access_control_post_id"] = "1"
      expect { prepare }.to raise_error(/protected destination/)
      expect(store).not_to have_received(:check!)
    end
  end

  it "preserves hosted objects, sends only missing files, and binds both inventories to the SQL launch" do
    already_hosted = original("destination", 1, "hosted bytes", hosted: true)
    incoming = original("source", 1, "local bytes")
    prepare
    expect(store).to have_received(:create).once
    expect(
      read do |state|
        state.validate!(
          rows,
          origins: configuration.data.values_at("source_url", "destination_url"),
        )
      end,
    ).to eq(target)
    read do |state|
      expect(state.receipt("source", "uploads", 1).fetch("relative")).to eq(incoming)
      expect(state.receipt("destination", "uploads", 1).fetch("relative")).to eq(already_hosted)
    end
    prepare
    expect(store).to have_received(:create).once
    expect(store).to have_received(:digests).once
    rows["source"]["uploads"].first["sha1"] = "0" * 40
    expect {
      read do |state|
        state.validate!(
          rows,
          origins: configuration.data.values_at("source_url", "destination_url"),
        )
      end
    }.to raise_error(/changed; rerun/)
  end

  it "prepares two local backups and rewrites direct, CDN and protected links while preserving Markdown upload identities" do
    dest = original("destination", 7, "destination")
    src = original("source", 7, "private", secure: true)
    prepare
    expect(store).to have_received(:create).twice
    expect(access).to include(dest => false, src => true)
    read do |state|
      media = BulkImport::DiscourseMerge::PreuploadedMedia.new(state, plan)
      map = {}
      %w[source destination].each do |side|
        result = state.receipt(side, "uploads", 7)
        media.map_urls(
          map,
          side,
          rows[side]["uploads"].first.fetch("url"),
          result,
          result.fetch("url"),
        )
      end
      refs =
        BulkImport::DiscourseMerge::References.new(
          source_host: "incoming.example",
          destination_host: "hosted.example",
          topics: {
          },
          categories: {
          },
          media_urls: map,
          upload_mode: "preuploaded",
        )
      expect(refs.rewrite("![a](upload://abc.png)")).to eq("![a](upload://abc.png)")
      expect(refs.rewrite(%(<img src="/uploads/default/#{dest}">), cooked: true)).to eq(
        %(<img src="https://cdn.example/uploads/final/#{dest}">),
      )
      expect(refs.rewrite("https://incoming.example/uploads/default/#{src}")).to eq(
        "https://hosted.example/secure-uploads/uploads/final/#{src}",
      )
      expect(refs.rewrite("https://incoming.example/uploads/short-url/abc.png")).to eq(
        "https://hosted.example/uploads/short-url/abc.png",
      )
    end
  end

  it "relocates bytes from an explicitly configured hosted input alongside a local destination" do
    old = original("source", 8, "hosted input")
    @directory.join("source", old).delete
    configuration.data.delete("source_upload_root")
    original("destination", 8, "local destination")
    target["read_prefixes"] = { "source" => "s3://old/uploads/tenant" }
    allow(store).to receive(:read_backup)
      .with("s3://old/uploads/tenant", old, false)
      .and_yield("hosted input")
      .and_return(true)
    prepare
    expect(store).to have_received(:read_backup).once
    expect(bytes.fetch(old)).to eq("hosted input")
    expect(read { |state| state.receipt("source", "uploads", 8) }.fetch("url")).to eq(
      store.location(old),
    )
  end

  it "keeps successful receipts, repairs missing objects, and prunes only surplus records" do
    good = original("source", 1, "good")
    missing = original("source", 2, "missing")
    file = @directory.join("source", missing)
    file.delete
    expect { prepare }.to raise_error(/1 unverified/)
    expect {
      read do |state|
        state.validate!(
          rows,
          origins: configuration.data.values_at("source_url", "destination_url"),
        )
      end
    }.to raise_error(/Incomplete/)
    expect(bytes).to include(good => "good")
    file.binwrite("missing")
    prepare
    bytes.delete(good)
    rows["source"]["uploads"].pop
    prepare
    expect(read { |state| state.receipt("source", "uploads", 2) }).to be_nil
    expect(bytes).to include(good => "good", missing => "missing")
    expect(
      read do |state|
        state.validate!(
          rows,
          origins: configuration.data.values_at("source_url", "destination_url"),
        )
      end,
    ).to eq(target)
  end

  it "remaps local and CDN avatars using destination account and upload IDs" do
    users = class_double("User").as_stubbed_const
    avatar_user = instance_double("User", encoded_username: "merged")
    allow(users).to receive(:unscoped).and_return(users)
    allow(users).to receive(:find).with(27).and_return(avatar_user)
    refs =
      BulkImport::DiscourseMerge::References.new(
        source_host: "incoming.example",
        destination_host: "hosted.example",
        topics: {
        },
        categories: {
        },
        users: {
          7 => 27,
        },
        uploads: {
          4 => 19,
        },
        usernames: {
          "old" => "merged",
        },
        media_origins: {
          "s3_base_url" => "//old-bucket.s3.example",
          "cdn_url" => "https://old-cdn.example",
        },
        upload_mode: "preuploaded",
      )
    urls = %w[
      https://old-cdn.example/user_avatar/incoming.example/old/48/4_3.png
      //old-bucket.s3.example/avatars/7/48/4_3.png
    ]
    expect(urls.map { |url| refs.rewrite(url, cooked: true) }.uniq).to eq(
      [
        "https://hosted.example/user_avatar/hosted.example/merged/48/19_#{OptimizedImage::VERSION}.png",
      ],
    )
  end

  it "blocks a wrong destination tenant before sending incoming files" do
    key = original("destination", 2, "already hosted", hosted: true)
    configuration.data.delete("destination_upload_root")
    rows["destination"]["uploads"].first[
      "url"
    ] = "//hosted.s3.us-east-1.amazonaws.com/uploads/another/#{key}"
    original("source", 3, "new incoming bytes")
    expect { prepare }.to raise_error(/unverified destination/)
    expect(store).not_to have_received(:create)
  end

  it "passes the frozen media verification and detects storage metadata changes after apply" do
    relative = original("source", 1, "document")
    prepare
    plan["upload_policy"] = {
      "reuse" => [],
      "receipt_sha256" => Digest::SHA256.file(state_path).hexdigest,
    }
    saved = read { |state| state.receipt("source", "uploads", 1) }
    record =
      Struct.new(:id, :url, :etag, :sha1, :secure?, :filesize, :access_control_post_id).new(
        15,
        store.location(relative),
        saved["etag"],
        saved["sha1"],
        false,
        saved["size"],
        nil,
      )
    uploads = class_double("Upload").as_stubbed_const
    thumbnails = class_double("OptimizedImage").as_stubbed_const
    empty = instance_double("ActiveRecord::Relation", exists?: false)
    allow(uploads).to receive(:unscoped).and_return(uploads)
    allow(uploads).to receive(:where).with(id: [15]).and_return([record])
    [uploads, thumbnails].each do |model|
      allow(model).to receive(:where).with(a_kind_of(String)).and_return(empty)
    end
    source = instance_double(PG::Connection)
    allow(source).to receive(:exec).with("SELECT id FROM uploads").and_return(
      instance_double(PG::Result, column_values: ["1"]),
    )
    allow(source).to receive(:exec).with("SELECT id FROM optimized_images").and_return(
      instance_double(PG::Result, column_values: []),
    )
    allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each_batch).with(
      source,
      /FROM upload_references/,
    )
    importer =
      Struct.new(:maps, :category_keys, :source_raw_connection).new(
        { uploads: { 1 => 15 }, optimized_images: {} },
        {},
        source,
      )
    verifier =
      BulkImport::DiscourseMerge::Verifier.new(importer, Struct.new(:data).new(plan), @directory)
    expect {
      verifier.check("prepared_media") { verifier.verify_prepared_media }
    }.not_to raise_error
    record.etag = "changed"
    expect { verifier.verify_prepared_media }.to raise_error(/Wrong prepared storage metadata/)
  end

  it "blocks changed targets, conflicting object bytes and invalid private access" do
    key = original("source", 5, "private", secure: true)
    prepare
    access[key] = false
    expect { prepare }.to raise_error(/1 unverified/)
    access[key] = true
    bytes[key] = "changed"
    expect { prepare }.to raise_error(/1 unverified/)
    expect(bytes[key]).to eq("changed")
    target["prefix"] = "other-tenant"
    expect { prepare }.to raise_error(/target or forum origins changed/)
  end

  it "records the bytes of a regenerated derivative and refuses a changed frozen ledger" do
    key = original("source", 1, "original")
    optimized = key.sub("original/", "optimized/").sub(".png", "_1_10x10.png")
    rows["source"]["optimized_images"] << {
      "id" => "4",
      "upload_id" => "1",
      "width" => "10",
      "height" => "10",
      "sha1" => "b" * 40,
      "filesize" => "999",
      "url" => "/uploads/default/#{optimized}",
    }
    stub_const("OptimizedImage", Class.new) unless defined?(OptimizedImage)
    allow(OptimizedImage).to receive(:resize) { |_, output, _, _, **_|
      File.binwrite(output, "resized")
    }
    prepare
    plan.fetch("upload_policy")["receipt_sha256"] = Digest::SHA256.file(state_path).hexdigest
    BulkImport::DiscourseMerge::PreuploadedMedia.open(plan, @directory) do |media|
      result = media.receipt("source", "optimized_images", 4)
      expect(result).to include(
        "generated" => true,
        "sha1" => Digest::SHA1.hexdigest("resized"),
        "size" => 7,
      )
      expect(result.fetch("parent_digest")).to eq(Digest::SHA256.hexdigest("original"))
    end
    prepare
    expect(OptimizedImage).to have_received(:resize).once
    expect {
      BulkImport::DiscourseMerge::PreuploadedMedia.open(plan, @directory) {}
    }.to raise_error(/differ from the reviewed plan/)
  end

  it "keeps the image worker alive across thumbnail batches" do
    thumbnails =
      %w[destination source].map do |side|
        key = original(side, 1, side)
        thumbnail = key.sub("original/", "optimized/").sub(".png", "_2_10x10.png")
        rows.fetch(side).fetch("optimized_images") << {
          "id" => "4",
          "upload_id" => "1",
          "width" => "10",
          "height" => "10",
          "sha1" => Digest::SHA1.hexdigest("archived thumbnail"),
          "url" => "/uploads/default/#{thumbnail}",
        }
        thumbnail
      end

    owner = nil
    allow(GlobalSetting).to receive(:enable_vips_image_processing).and_return(true)
    allow(DiscourseVips).to receive(:version) { owner ||= Thread.current }
    allow(OptimizedImage).to receive(:resize) do |_, output, _, _, **_|
      owner ||= Thread.current
      raise "image worker lost its spawning thread" unless owner.alive?
      File.binwrite(output, "regenerated")
    end

    prepare

    expect(bytes.values_at(*thumbnails)).to eq(%w[regenerated regenerated])
  end

  it "regenerates a PNG from a GIF and retries a disconnected image worker before uploading" do
    key = original("source", 1, "original gif")
    gif = key.sub(/\.png\z/, ".gif")
    @directory.join("source", key).rename(@directory.join("source", gif))
    rows["source"]["uploads"].first.merge!(
      "url" => "/uploads/default/#{gif}",
      "extension" => "gif",
      "original_filename" => "original.gif",
    )
    thumbnail = key.sub("original/", "optimized/").sub(".png", "_2_10x10.png")
    rows["source"]["optimized_images"] << {
      "id" => "4",
      "upload_id" => "1",
      "width" => "10",
      "height" => "10",
      "sha1" => "f" * 40,
      "filesize" => "42",
      "url" => "/uploads/default/#{thumbnail}",
    }
    stub_const("OptimizedImage", Class.new) unless defined?(OptimizedImage)
    attempts = 0
    allow(OptimizedImage).to receive(:resize) do |input, output, width, height, **options|
      expect(File.extname(input)).to eq(".gif")
      expect([width, height, options]).to eq([10, 10, { format: "png", raise_on_error: true }])
      attempts += 1
      raise DiscourseVips::WorkerUnavailable if attempts == 1
      File.binwrite(output, "rendered png")
    end
    prepare
    expect(attempts).to eq(2)
    expect(bytes).to eq(gif => "original gif", thumbnail => "rendered png")
    expect(store).to have_received(:create).twice
  end

  it "uses Discourse's ImageMagick resize when Vips rejects an otherwise decodable JPEG" do
    key = original("source", 1, "archival JPEG")
    jpeg = key.sub(/\.png\z/, ".jpeg")
    @directory.join("source", key).rename(@directory.join("source", jpeg))
    rows["source"]["uploads"].first["url"] = "/uploads/default/#{jpeg}"
    image = jpeg.sub("original/", "optimized/").sub(".jpeg", "_2_30x20.jpeg")
    rows["source"]["optimized_images"] << {
      "id" => "5",
      "upload_id" => "1",
      "width" => "30",
      "height" => "20",
      "sha1" => "f" * 40,
      "filesize" => "42",
      "url" => "/uploads/default/#{image}",
    }
    stub_const("OptimizedImage", Class.new) unless defined?(OptimizedImage)
    allow(OptimizedImage).to receive(:resize).and_raise(DiscourseVips::InvalidImage)
    allow(OptimizedImage).to receive(:optimize) do |operation, input, output, dimensions, options|
      expect(operation).to eq(:optimized_image_resize)
      expect(File.binread(input)).to eq("archival JPEG")
      expect(dimensions).to eq("30x20")
      expect(options).to eq(format: "jpeg", raise_on_error: true)
      File.binwrite(output, "JPEG thumbnail")
    end
    prepare
    expect(OptimizedImage).to have_received(:optimize).once
    expect(bytes.fetch(image)).to eq("JPEG thumbnail")
  end
end
