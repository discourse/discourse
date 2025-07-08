# frozen_string_literal: true

Propshaft::Asset.prepend(
  Module.new do
    def already_digested?
      logical_path.to_s.start_with?("chunk.") || super
    end
  end,
)

Propshaft::Helper.prepend(
  Module.new do
    def compute_asset_path(path, options = {})
      attempts = 0
      begin
        super
      rescue Propshaft::MissingAssetError => e
        if Rails.env.development?
          # Ember-cli might've replaced the assets
          Rails.application.assets.load_path.send(:clear_cache)
          attempts += 1
          retry if attempts < 3
        elsif Rails.env.test?
          # Assets might not be compiled in test mode. Just return a fake path
          "/assets/#{path.sub(".", "-aaaaaaaa.")}"
        else
          raise e
        end
      end
    end
  end,
)

Propshaft::Compiler::SourceMappingUrls.prepend(
  Module.new do
    def source_mapping_url(*args)
      # Propshaft insists on converting sourcemap URLs to absolute paths. We want to keep
      # relative paths so that we can serve assets from different subdirectories without needing
      # to recompile them
      super.gsub(%r{sourceMappingURL=\S+/([^/]+\.map)}, 'sourceMappingURL=\1')
    end
  end,
)
