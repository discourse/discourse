# frozen_string_literal: true

RSpec.describe BlockLayoutUploads do
  describe ".extract" do
    it "returns an empty array for nil" do
      expect(described_class.extract(nil)).to eq([])
    end

    it "returns an empty array for an empty string" do
      expect(described_class.extract("")).to eq([])
    end

    it "returns an empty array for malformed JSON without raising" do
      expect(described_class.extract("{not json")).to eq([])
      expect(described_class.extract("[1, 2,")).to eq([])
    end

    it "returns an empty array when the layout contains no images" do
      json = { "schema_version" => 1, "layout" => [{ "block" => "wf:text" }] }.to_json
      expect(described_class.extract(json)).to eq([])
    end

    it "collects a single upload id from a source: upload image arg" do
      json = layout_with_image(source: "upload", upload_id: 42)
      expect(described_class.extract(json)).to eq([42])
    end

    it "skips external URL images (source: url) without an upload_id" do
      json = layout_with_image(source: "url")
      expect(described_class.extract(json)).to eq([])
    end

    it "skips an image with source: url even if upload_id is present" do
      # `source` gates the claim; an external URL must never claim an Upload
      # row even if the client misbehaves and sets `upload_id`.
      json = layout_with_image(source: "url", upload_id: 99)
      expect(described_class.extract(json)).to eq([])
    end

    it "skips an image with source: upload but no upload_id" do
      json = layout_with_image(source: "upload")
      expect(described_class.extract(json)).to eq([])
    end

    it "skips an image with a non-integer upload_id" do
      json = layout_with_image(source: "upload", upload_id: "42")
      expect(described_class.extract(json)).to eq([])

      json = layout_with_image(source: "upload", upload_id: 1.5)
      expect(described_class.extract(json)).to eq([])

      json = layout_with_image(source: "upload", upload_id: nil)
      expect(described_class.extract(json)).to eq([])
    end

    it "skips an image with a non-positive upload_id" do
      json = layout_with_image(source: "upload", upload_id: 0)
      expect(described_class.extract(json)).to eq([])

      json = layout_with_image(source: "upload", upload_id: -7)
      expect(described_class.extract(json)).to eq([])
    end

    it "collects both light and dark variant upload ids" do
      json = {
        "layout" => [
          {
            "block" => "wf:image",
            "args" => {
              "image" => {
                "source" => "upload",
                "upload_id" => 10,
                "url" => "/uploads/light.png",
                "dark" => {
                  "source" => "upload",
                  "upload_id" => 11,
                  "url" => "/uploads/dark.png",
                },
              },
            },
          },
        ],
      }.to_json

      expect(described_class.extract(json)).to contain_exactly(10, 11)
    end

    it "deduplicates the same upload used as both light and dark" do
      json = {
        "layout" => [
          {
            "args" => {
              "image" => {
                "source" => "upload",
                "upload_id" => 5,
                "url" => "/u.png",
                "dark" => {
                  "source" => "upload",
                  "upload_id" => 5,
                  "url" => "/u.png",
                },
              },
            },
          },
        ],
      }.to_json

      expect(described_class.extract(json)).to eq([5])
    end

    it "deduplicates the same upload referenced from multiple blocks" do
      json = {
        "layout" => [
          {
            "args" => {
              "image" => {
                "source" => "upload",
                "upload_id" => 7,
                "url" => "/a.png",
              },
            },
          },
          {
            "args" => {
              "image" => {
                "source" => "upload",
                "upload_id" => 7,
                "url" => "/a.png",
              },
            },
          },
        ],
      }.to_json

      expect(described_class.extract(json)).to eq([7])
    end

    it "finds image args nested deep inside containers" do
      inner = {
        "args" => {
          "image" => {
            "source" => "upload",
            "upload_id" => 99,
            "url" => "/deep.png",
          },
        },
      }
      nested = inner
      6.times { nested = { "block" => "wf:container", "children" => [nested] } }
      json = { "layout" => [nested] }.to_json

      expect(described_class.extract(json)).to eq([99])
    end

    it "collects only the upload-backed image when mixed with an external URL" do
      json = {
        "layout" => [
          {
            "args" => {
              "image" => {
                "source" => "upload",
                "upload_id" => 1,
                "url" => "/u.png",
              },
            },
          },
          { "args" => { "image" => { "source" => "url", "url" => "https://cdn.example/x.png" } } },
        ],
      }.to_json

      expect(described_class.extract(json)).to eq([1])
    end

    it "collects multiple distinct upload ids in declaration order, deduped" do
      json = {
        "layout" => [
          { "args" => { "a" => { "source" => "upload", "upload_id" => 1, "url" => "/1.png" } } },
          { "args" => { "b" => { "source" => "upload", "upload_id" => 2, "url" => "/2.png" } } },
          { "args" => { "c" => { "source" => "upload", "upload_id" => 1, "url" => "/1.png" } } },
        ],
      }.to_json

      expect(described_class.extract(json)).to eq([1, 2])
    end

    it "is shape-driven: any nested object that looks like an upload reference is collected" do
      # This is intentional — by NOT requiring the wrapper to be an arg slot,
      # the extractor stays decoupled from arg-naming conventions and future
      # blocks "just work". The collision risk is negligible because the
      # shape (source: upload + integer upload_id) is specific to image args.
      json = { "weirdly_placed" => { "source" => "upload", "upload_id" => 77 } }.to_json
      expect(described_class.extract(json)).to eq([77])
    end

    it "ignores non-Hash / non-Array leaves without raising" do
      json = {
        "layout" => [
          { "args" => { "title" => "hello", "count" => 3, "enabled" => true } },
          nil,
          "stray-string",
        ],
      }.to_json

      expect(described_class.extract(json)).to eq([])
    end
  end

  OMIT = Object.new.freeze

  def layout_with_image(source:, upload_id: OMIT)
    image = { "url" => "/uploads/a.png", "source" => source }
    image["upload_id"] = upload_id unless upload_id.equal?(OMIT)
    { "layout" => [{ "args" => { "image" => image } }] }.to_json
  end
end
