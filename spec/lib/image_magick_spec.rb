# frozen_string_literal: true

require "image_magick"

RSpec.describe ImageMagick do
  describe ".asset_read_paths" do
    it "includes the system Fontconfig cache when it exists" do
      fontconfig_cache_path = "/var/cache/fontconfig"
      skip "system Fontconfig cache is unavailable" if !Dir.exist?(fontconfig_cache_path)

      expect(described_class.asset_read_paths).to include(fontconfig_cache_path)
    end
  end

  describe ".magick" do
    it "resolves the letter-avatar font without modifying the system Fontconfig cache" do
      fontconfig_cache_path = "/var/cache/fontconfig"
      skip "Landlock is unavailable" if !Discourse::SafeExec.landlock_supported?
      skip "system Fontconfig cache is unavailable" if !Dir.exist?(fontconfig_cache_path)

      cache_files =
        Dir
          .glob(File.join(fontconfig_cache_path, "*"), File::FNM_DOTMATCH)
          .select { |path| File.file?(path) }
      cache_before =
        cache_files.to_h do |path|
          [File.basename(path), [File.mtime(path), Digest::SHA256.file(path).hexdigest]]
        end

      fonts = described_class.magick("-list", "font")

      cache_after =
        cache_files.to_h do |path|
          [File.basename(path), [File.mtime(path), Digest::SHA256.file(path).hexdigest]]
        end
      expect(fonts).to include("NimbusSans-Regular")
      expect(cache_after).to eq(cache_before)
    end
  end
end
