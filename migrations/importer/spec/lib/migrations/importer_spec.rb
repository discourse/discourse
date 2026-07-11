# frozen_string_literal: true

RSpec.describe Migrations::Importer do
  describe ".resolve_config_defaults" do
    let(:intermediate_db) { "/shared/import/intermediate.db" }
    let(:derived_files_db) { "/shared/import/files.db" }
    let(:derived_cache) { "/shared/import/downloads" }

    it "derives files_db next to the intermediate_db when it exists on disk" do
      allow(File).to receive(:exist?).with(derived_files_db).and_return(true)
      config = { intermediate_db: }

      described_class.resolve_config_defaults(config)

      expect(config[:files_db]).to eq(derived_files_db)
    end

    it "leaves files_db blank (inline mode) when the derived file is missing" do
      allow(File).to receive(:exist?).with(derived_files_db).and_return(false)
      config = { intermediate_db: }

      described_class.resolve_config_defaults(config)

      expect(config[:files_db]).to be_nil
    end

    it "keeps an explicit files_db without touching the disk" do
      config = { intermediate_db:, files_db: "/elsewhere/files.db" }

      described_class.resolve_config_defaults(config)

      expect(config[:files_db]).to eq("/elsewhere/files.db")
    end

    it "derives the inline download_cache_path when the uploads section omits it" do
      allow(File).to receive(:exist?).and_return(false)
      config = { intermediate_db:, config: { uploads: { root_paths: ["/x"] } } }

      described_class.resolve_config_defaults(config)

      expect(config.dig(:config, :uploads, :download_cache_path)).to eq(derived_cache)
    end

    it "keeps an explicit inline download_cache_path" do
      allow(File).to receive(:exist?).and_return(false)
      config = { intermediate_db:, config: { uploads: { download_cache_path: "/custom/cache" } } }

      described_class.resolve_config_defaults(config)

      expect(config.dig(:config, :uploads, :download_cache_path)).to eq("/custom/cache")
    end

    it "does not add an uploads section when there is none" do
      allow(File).to receive(:exist?).and_return(false)
      config = { intermediate_db:, config: { always_allow_reserved_usernames: true } }

      described_class.resolve_config_defaults(config)

      expect(config[:config]).not_to have_key(:uploads)
    end
  end
end
