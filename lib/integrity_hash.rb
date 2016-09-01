class Discourse::IntegrityHash

  def self.new_hash
    Digest::SHA2.new
  end

  def self.for_asset(asset_name)
    return '' unless SiteSetting.use_integrity_hashes
    asset = Rails.application.assets[asset_name]
    @integrity_hashes ||= {}
    if !@integrity_hashes[asset_name] || @integrity_hashes[asset_name][:mtime] != asset.mtime
      if Rails.env.production?
        if asset_name == 'vendor'
          # FIXME https://code.google.com/p/chromium/issues/detail?id=527286
          return ''
        end
        @integrity_hashes[asset_name] = {
          digest: for_file(File.join(Rails.root, 'public/assets', asset.digest_path)),
          mtime: asset.mtime
        }
      else
        digest = new_hash
        coder = {}
        asset.encode_with(coder)
        digest.update(coder['source'])
        @integrity_hashes[asset_name] = {
          digest: "sha256-#{digest.base64digest}",
          mtime: asset.mtime
        }
      end
    end
    @integrity_hashes[asset_name][:digest]
  end

  def self.for_file(filename)
    return '' unless SiteSetting.use_integrity_hashes
    digest = new_hash
    File.open(filename, 'r') do |f|
      digest.update(f.read(2**16)) until f.eof?
    end
    "sha256-#{digest.base64digest}"
  end

  def self.for_string(content)
    return '' unless SiteSetting.use_integrity_hashes
    "sha256-#{new_hash.base64digest(content)}"
  end
end
