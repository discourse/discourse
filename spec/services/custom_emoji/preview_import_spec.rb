# frozen_string_literal: true

require "zip"

RSpec.describe CustomEmoji::PreviewImport do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:file) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)

    let(:params) { { file: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:image_path) { Rails.root.join("spec/fixtures/images/logo.png") }
    let(:csv_content) { "name,group,filename\npreview-emoji,,preview-emoji.png\n" }
    let(:images) { { "preview-emoji.png" => image_path } }
    let(:file) { build_emoji_zip(csv_content, images) }

    def build_emoji_zip(csv_content, images = {})
      tmp = Tempfile.new(%w[emoji_import_ .zip])
      tmp.close

      Zip::File.open(tmp.path, create: true) do |zip|
        zip.get_output_stream("emojis.csv") { |entry| entry.write(csv_content) } if csv_content
        images.each { |filename, path| zip.add(filename, path) }
      end

      Rack::Test::UploadedFile.new(tmp.path, "application/zip")
    end

    context "when contract is invalid" do
      let(:file) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the ZIP has no emojis.csv entry" do
      let(:file) do
        tmp = Tempfile.new(%w[no_csv_ .zip])
        tmp.close
        Zip::File.open(tmp.path, create: true) do |zip|
          zip.get_output_stream("readme.txt") { |entry| entry.write("hi") }
        end
        Rack::Test::UploadedFile.new(tmp.path, "application/zip")
      end

      it { is_expected.to fail_with_exception(Compression::SafeZipReader::MissingEntryError) }
    end

    context "when the manifest only contains headers" do
      let(:csv_content) { "name,group,filename\n" }
      let(:images) { {} }

      it { is_expected.to fail_a_policy(:manifest_not_empty) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns a token and the staged rows with their categories" do
        expect(result[:token]).to be_present
        expect(result[:rows].map { |row| [row.name, row.category] }).to eq(
          [["preview-emoji", CustomEmoji::ImportRow::CATEGORY_NEW]],
        )
      end

      it "stores the staged rows in Redis under the user and token" do
        expect(
          Discourse.redis.exists?("emoji_import_preview:#{current_user.id}:#{result[:token]}"),
        ).to eq(true)
      end

      it "creates a staged upload retained for three hours" do
        expect { result }.to change { Upload.count }.by(1)
        expect(Upload.last.retain_hours).to eq(3)
      end
    end
  end
end
