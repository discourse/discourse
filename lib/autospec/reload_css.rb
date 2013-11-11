module Autospec; end
class Autospec::ReloadCss

  MATCHERS = {}
  def self.watch(pattern, &blk)
    MATCHERS[pattern] = blk
  end

  watch(/tmp\/refresh_browser/)
  watch(/\.css$/)
  watch(/\.css\.erb$/)
  watch(/\.sass$/)
  watch(/\.scss$/)
  watch(/\.sass\.erb$/)
  watch(/\.handlebars$/)

  def self.message_bus
    MessageBus::Instance.new.tap do |bus|
      bus.site_id_lookup do
        # this is going to be dev the majority of the time, if you have multisite configured in dev stuff may be different
        "default"
      end
    end
  end

  def self.run_on_change(paths)
    paths.map! do |p|
      hash = nil
      fullpath = Rails.root.to_s + "/" + p
      hash = Digest::MD5.hexdigest(File.read(fullpath)) if File.exists? fullpath
      p = p.sub /\.sass\.erb/, ""
      p = p.sub /\.sass/, ""
      p = p.sub /\.scss/, ""
      p = p.sub /^app\/assets\/stylesheets/, "assets"
      {name: p, hash: hash}
    end
    message_bus.publish "/file-change", paths
  end

end
