# frozen_string_literal: true

require "zip"

RSpec.describe CustomEmoji::Action::ParseImportManifest do
  describe "#call" do
    subject(:rows) { parse_manifest(csv_content) }

    def parse_manifest(csv_content)
      tmp = Tempfile.new(%w[manifest_ .zip])
      tmp.close

      Zip::File.open(tmp.path, create: true) do |zip|
        zip.get_output_stream("emojis.csv") { |entry| entry.write(csv_content) }
      end

      Compression::SafeZipReader.open(tmp.path) { |reader| described_class.call(reader:) }
    ensure
      tmp.unlink
    end

    context "with valid rows" do
      let(:csv_content) { "name,group,filename\nparty,Fun,party.png\nblob,,blob.gif\n" }

      it "returns one uncategorized row per CSV row with normalized attributes" do
        expect(rows.map { [it.name, it.group, it.filename, it.category] }).to eq(
          [["party", "fun", "party.png", nil], ["blob", nil, "blob.gif", nil]],
        )
      end
    end

    context "with names needing sanitization" do
      let(:csv_content) { "name,group,filename\nMy Emoji!,,my-emoji.png\n" }

      it "sanitizes the name" do
        expect(rows.first.name).to eq("my_emoji_")
      end
    end

    context "with a group matching the default group" do
      let(:csv_content) do
        "name,group,filename\none,Default,one.png\ntwo,default,two.png\nthree,,three.png\n"
      end

      it "normalizes the group to nil" do
        expect(rows.map(&:group)).to eq([nil, nil, nil])
      end
    end

    context "with a missing name" do
      let(:csv_content) { "name,group,filename\n,,unnamed.png\n" }

      it "marks the row invalid" do
        expect(rows.first).to be_invalid
        expect(rows.first.errors).to eq([I18n.t("emoji.import.validation.missing_name")])
      end
    end

    context "with two names identical after sanitization" do
      let(:csv_content) { "name,group,filename\nMy Emoji!,,first.png\nmy emoji?,,second.png\n" }

      it "marks the second row invalid" do
        expect(rows.first).not_to be_invalid
        expect(rows.second).to be_invalid
        expect(rows.second.errors).to eq([I18n.t("emoji.import.validation.duplicate_name")])
      end
    end

    context "with a missing filename" do
      let(:csv_content) { "name,group,filename\nno-file,,\n" }

      it "marks the row invalid" do
        expect(rows.first).to be_invalid
        expect(rows.first.errors).to eq([I18n.t("emoji.import.validation.missing_filename")])
      end
    end

    context "with an unsupported file extension" do
      let(:csv_content) { "name,group,filename\nbad-ext,,bad-ext.bmp\n" }

      it "marks the row invalid" do
        expect(rows.first).to be_invalid
        expect(rows.first.errors).to eq(
          [I18n.t("emoji.import.validation.unsupported_extension", ext: "bmp")],
        )
      end
    end

    context "with a duplicate filename" do
      let(:csv_content) { "name,group,filename\nfirst,,shared.png\nsecond,,shared.png\n" }

      it "marks the second row invalid" do
        expect(rows.first).not_to be_invalid
        expect(rows.second).to be_invalid
        expect(rows.second.errors).to eq([I18n.t("emoji.import.validation.duplicate_filename")])
      end
    end

    context "with a group longer than the maximum length" do
      let(:csv_content) { "name,group,filename\nlong-group,#{"g" * 21},long-group.png\n" }

      it "marks the row invalid" do
        expect(rows.first).to be_invalid
        expect(rows.first.errors).to eq([I18n.t("emoji.import.validation.group_too_long")])
      end
    end
  end
end
