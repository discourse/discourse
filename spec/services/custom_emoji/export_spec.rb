# frozen_string_literal: true

require "zip"
require "csv"

RSpec.describe CustomEmoji::Export do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:names) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:current_user, :admin)
    fab!(:png_upload) do
      UploadCreator.new(
        file_from_fixtures("logo.png"),
        "logo.png",
        type: "custom_emoji",
      ).create_for(Discourse.system_user.id)
    end
    fab!(:default_group_emoji) { Fabricate(:custom_emoji, name: "emoji-a", upload: png_upload) }
    fab!(:grouped_emoji) do
      Fabricate(:custom_emoji, name: "emoji-b", upload: png_upload, group: "fun")
    end

    let(:params) { { names: } }
    let(:dependencies) { { guardian: current_user.guardian } }
    let(:names) { %w[emoji-a emoji-b] }

    context "when contract is invalid" do
      let(:names) { ["", nil] }

      it { is_expected.to fail_a_contract }
    end

    context "when no emojis match the provided names" do
      let(:names) { ["nonexistent-emoji"] }

      it { is_expected.to fail_to_find_a_model(:emojis) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "builds a ZIP archive containing the manifest and one image per emoji" do
        with_archive do |zip|
          expect(zip.entries.map(&:name)).to contain_exactly(
            "emojis.csv",
            "emoji-a.png",
            "emoji-b.png",
          )
        end
      end

      it "writes a manifest row per emoji with a blank group for the default group" do
        with_archive do |zip|
          manifest = CSV.parse(zip.read("emojis.csv"), headers: true)

          expect(manifest.map { |row| row.to_h.slice("name", "group", "filename") }).to eq(
            [
              { "name" => "emoji-a", "group" => nil, "filename" => "emoji-a.png" },
              { "name" => "emoji-b", "group" => "fun", "filename" => "emoji-b.png" },
            ],
          )
        end
      end

      def with_archive
        Tempfile.create(%w[emoji_export_ .zip]) do |file|
          file.binmode
          file.write(result[:archive])
          file.rewind

          Zip::File.open(file.path) { |zip| yield(zip) }
        end
      end
    end
  end
end
