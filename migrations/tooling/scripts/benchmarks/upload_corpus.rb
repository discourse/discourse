# frozen_string_literal: true

# Deterministic corpus generator for the upload benchmarks.
#
# Builds a directory of synthetic files (images + binary attachments) plus a
# matching IntermediateDB SQLite whose `upload_sources` rows point at them, so
# the real Uploader task can consume the corpus unchanged. Everything is derived
# from a single seed: the same seed always produces the same bytes, so runs are
# reproducible and comparable.
#
# This script does NOT need Rails (only ImageMagick's `magick` and the migrations
# SQLite helpers). Run it standalone to inspect a corpus:
#
#   CORPUS_DIR=/tmp/upload_corpus CORPUS_IMAGES=60 CORPUS_ATTACHMENTS=20 \
#     ruby migrations/tooling/scripts/benchmarks/upload_corpus.rb
#
# Configuration (env vars):
#   CORPUS_DIR             where to write files + corpus.sqlite3 (required standalone)
#   CORPUS_SEED            base RNG seed (default 1234)
#   CORPUS_IMAGES          number of images (default 60)
#   CORPUS_ATTACHMENTS     number of binary attachments (default 20)
#   CORPUS_MAX_ATTACH_MB   largest attachment in MB (default 10, bump for ~100MB)
#
# The scaling and profile scripts require this file and call
# UploadBench::Corpus.generate(...) directly, so they can build a fresh,
# uniquely-seeded corpus per run.

require_relative "upload_bench_support"
UploadBench.setup!

require "fileutils"
require "open3"
require "securerandom"

module UploadBench
  class Corpus
    Result =
      Struct.new(
        :db_path,
        :files_dir,
        :root_dir,
        :image_count,
        :attachment_count,
        :total_bytes,
        keyword_init: true,
      )

    # Deterministic image tiers, cycled over the requested image count. All
    # images are incompressible noise rendered through ImageMagick's `xc:`/
    # `+noise` coder (Discourse's ImageMagick policy blocks pseudo-coders like
    # `gradient:`, so we stick to what the real infra allows). Dimensions,
    # format and quality spread file sizes from ~40 KB to several MB and exercise
    # every UploadCreator image branch:
    #   * small JPEG + small GIF (fast path, optimization skipped for GIF)
    #   * sub-megapixel PNGs (kept as PNG -> oxipng level 3)
    #   * >0.92 MP PNG (converted to JPEG)
    #   * multi-MB JPEGs (recompress + maybe downsize!)
    # No single PNG exceeds the 2 MP cap above which UploadCreator skips oxipng.
    IMAGE_TIERS = [
      { w: 420, h: 320, fmt: "jpg", q: 72 },
      { w: 700, h: 500, fmt: "gif" },
      { w: 900, h: 650, fmt: "png" },
      { w: 1000, h: 750, fmt: "png" },
      { w: 1200, h: 900, fmt: "png" },
      { w: 800, h: 600, fmt: "jpg", q: 80 },
      { w: 1280, h: 960, fmt: "jpg", q: 85 },
      { w: 2000, h: 1500, fmt: "jpg", q: 90 },
      { w: 3000, h: 2200, fmt: "jpg", q: 92 },
    ].freeze

    ATTACHMENT_EXTS = %w[pdf zip bin].freeze

    def self.generate(**kwargs)
      new(**kwargs).generate
    end

    def initialize(
      dir:,
      seed: 1234,
      images: 60,
      attachments: 20,
      max_attachment_bytes: 10 * 1024 * 1024
    )
      @root_dir = File.expand_path(dir)
      @files_dir = File.join(@root_dir, "files")
      @db_path = File.join(@root_dir, "corpus.sqlite3")
      @seed = seed
      @images = images
      @attachments = attachments
      @max_attachment_bytes = max_attachment_bytes
    end

    def generate
      ensure_magick!
      FileUtils.rm_rf(@root_dir)
      FileUtils.mkdir_p(@files_dir)

      Migrations::Database.migrate(
        @db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )

      total_bytes = 0
      db = Migrations::Database.connect(@db_path)
      begin
        total_bytes += write_images(db)
        total_bytes += write_attachments(db)
        db.commit_transaction
      ensure
        db.close
      end

      Result.new(
        db_path: @db_path,
        files_dir: @files_dir,
        root_dir: @root_dir,
        image_count: @images,
        attachment_count: @attachments,
        total_bytes:,
      )
    end

    private

    def write_images(db)
      bytes = 0
      @images.times do |i|
        tier = IMAGE_TIERS[i % IMAGE_TIERS.size]
        name = format("img_%05d.%s", i + 1, tier[:fmt])
        path = File.join(@files_dir, name)
        render_image(tier, path, @seed + i)
        bytes += File.size(path)
        insert_row(db, path:, filename: name, type: 1) # 1 = image-ish; type is unused by find-in-paths
      end
      bytes
    end

    def write_attachments(db)
      bytes = 0
      @attachments.times do |i|
        ext = ATTACHMENT_EXTS[i % ATTACHMENT_EXTS.size]
        name = format("att_%05d.%s", i + 1, ext)
        path = File.join(@files_dir, name)
        size = attachment_size(i)
        write_random_bytes(path, size, @seed + 100_000 + i)
        bytes += size
        insert_row(db, path:, filename: name, type: 2)
      end
      bytes
    end

    # Spread attachment sizes deterministically between ~100 KB and the cap.
    def attachment_size(index)
      return @max_attachment_bytes if @attachments <= 1

      min = 100 * 1024
      span = @max_attachment_bytes - min
      min + (span * index / (@attachments - 1))
    end

    def render_image(tier, path, seed)
      args = ["-size", "#{tier[:w]}x#{tier[:h]}", "-seed", seed.to_s, "xc:", "+noise", "Random"]
      args += ["-quality", tier[:q].to_s] if tier[:q]
      # Strip metadata so the same seed yields identical bytes: ImageMagick
      # otherwise stamps PNGs with a creation timestamp.
      args << "-strip"
      args << path

      _out, status = Open3.capture2e("magick", *args)
      unless status.success? && File.exist?(path)
        raise Error, "magick failed for #{path}: #{_out.strip}"
      end
    end

    # Deterministic pseudo-random bytes for a non-image attachment. A tiny header
    # keeps sniffers from choking; the rest is incompressible noise so sha1 and
    # store I/O see a realistic payload.
    def write_random_bytes(path, size, seed)
      rng = Random.new(seed)
      chunk = 256 * 1024
      File.open(path, "wb") do |f|
        f.write(header_for(File.extname(path)))
        remaining = size - f.pos
        while remaining > 0
          n = [chunk, remaining].min
          f.write(rng.bytes(n))
          remaining -= n
        end
      end
    end

    def header_for(ext)
      case ext
      when ".pdf"
        "%PDF-1.4\n"
      when ".zip"
        "PK\x03\x04".b
      else
        "BENCHMARK\n"
      end
    end

    def insert_row(db, path:, filename:, type:)
      db.insert(
        "INSERT OR IGNORE INTO upload_sources (id, filename, path, type) VALUES (?, ?, ?, ?)",
        [Migrations::ID.hash(path), filename, path, type],
      )
    end

    def ensure_magick!
      return if system("magick", "-version", out: File::NULL, err: File::NULL)
      raise Error, "ImageMagick `magick` binary not found on PATH"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  dir = ENV["CORPUS_DIR"] or abort "Set CORPUS_DIR to the target directory"
  result =
    UploadBench::Corpus.generate(
      dir:,
      seed: UploadBench.env_int("CORPUS_SEED", 1234),
      images: UploadBench.env_int("CORPUS_IMAGES", 60),
      attachments: UploadBench.env_int("CORPUS_ATTACHMENTS", 20),
      max_attachment_bytes: UploadBench.env_int("CORPUS_MAX_ATTACH_MB", 10) * 1024 * 1024,
    )

  mb = (result.total_bytes.to_f / (1024 * 1024)).round(1)
  puts "Corpus written to #{result.root_dir}"
  puts "  db:          #{result.db_path}"
  puts "  files:       #{result.image_count} images + #{result.attachment_count} attachments"
  puts "  total bytes: #{mb} MB"
end
