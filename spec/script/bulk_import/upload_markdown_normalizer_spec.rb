# frozen_string_literal: true

require "rails_helper"
require_relative "../../../script/bulk_import/upload_markdown_normalizer"

RSpec.describe UploadMarkdownNormalizer do
  # Number of uploads that actually render as media in the cooked output — i.e. the uploads that
  # would gain an upload_reference. This is the behaviour each fix is meant to restore.
  def rendered_upload_count(raw)
    PrettyText.cook(raw).scan(%r{data-orig-(?:src|href)="upload://[^"]+"}).size
  end

  describe ".normalize" do
    it "makes an upload inside a GFM table cell cook to an image" do
      raw = "| Col |\n| --- |\n| ![cat|40x24](upload://abc123.png) |"

      expect(rendered_upload_count(raw)).to eq(0)
      expect(rendered_upload_count(described_class.normalize(raw))).to eq(1)
    end

    it "makes an upload inside a block HTML tag cook to an image" do
      raw = "<table>\n<tr><td>![cat|96x96](upload://abc123.gif)</td></tr>\n</table>"

      expect(rendered_upload_count(raw)).to eq(0)
      expect(rendered_upload_count(described_class.normalize(raw))).to eq(1)
    end

    it "makes an indented upload line cook to an image instead of a code block" do
      raw = "Intro\n\n            ![cat|10x10](upload://abc123.png)\n\nOutro"

      expect(rendered_upload_count(raw)).to eq(0)
      expect(rendered_upload_count(described_class.normalize(raw))).to eq(1)
    end

    it "leaves an already-correct inline upload unchanged" do
      raw = "see ![cat|40x24](upload://abc123.png) here"

      expect(described_class.normalize(raw)).to eq(raw)
    end

    it "is idempotent" do
      raw =
        "| ![a|40x24](upload://a.png) |\n\n<td>![b|1x1](upload://b.png)</td>\n\n    ![c|2x2](upload://c.png)"
      once = described_class.normalize(raw)

      expect(described_class.normalize(once)).to eq(once)
    end
  end

  describe ".escape_table_pipes" do
    it "escapes the dimension pipe inside a table row" do
      expect(described_class.escape_table_pipes("| ![c|40x24](upload://a.png) |")).to eq(
        "| ![c\\|40x24](upload://a.png) |",
      )
    end

    it "leaves a non-table upload pipe untouched" do
      raw = "![c|40x24](upload://a.png)"

      expect(described_class.escape_table_pipes(raw)).to eq(raw)
    end
  end

  describe ".dedent_upload_lines" do
    it "de-indents a standalone indented upload line" do
      expect(described_class.dedent_upload_lines("    ![c|1x1](upload://a.png)")).to eq(
        "![c|1x1](upload://a.png)",
      )
    end

    it "preserves indentation of a list-continuation upload" do
      raw = "- item\n\n    ![c|1x1](upload://a.png)"

      expect(described_class.dedent_upload_lines(raw)).to eq(raw)
    end
  end
end
