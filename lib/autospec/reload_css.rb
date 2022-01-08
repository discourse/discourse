# frozen_string_literal: true

module Autospec; end

class Autospec::ReloadCss

  WATCHERS = {}
  def self.watch(pattern, &blk)
    WATCHERS[pattern] = blk
  end

  # css, scss, sass or handlebars
  watch(/\.css$/)
  watch(/\.ca?ss\.erb$/)
  watch(/\.s[ac]ss$/)
  watch(/\.hbs$/)
  watch(/\.hbr$/)

  def self.message_bus
    MessageBus::Instance.new.tap do |bus|
      bus.site_id_lookup do
        # this is going to be dev the majority of the time
        # if you have multisite configured in dev stuff may be different
        "default"
      end
    end
  end

  def self.run_on_change(paths)
    if paths.any? { |p| p =~ /\.(css|s[ac]ss)/ }
      # todo connect to dev instead?
      ActiveRecord::Base.establish_connection
      [:desktop, :mobile].each do |style|
        s = DiscourseStylesheets.new(style)
        s.compile
        paths << "public" + s.stylesheet_relpath_no_digest
      end
      ActiveRecord::Base.clear_active_connections!
    end
    paths.map! do |p|
      hash = nil
      fullpath = "#{Rails.root}/#{p}"
      hash = Digest::MD5.hexdigest(File.read(fullpath)) if File.exist?(fullpath)
      p = p.sub(/\.sass\.erb/, "")
      p = p.sub(/\.sass/, "")
      p = p.sub(/\.scss/, "")
      p = p.sub(/^app\/assets\/stylesheets/, "assets")
      { name: p, hash: hash || SecureRandom.hex }
    end
    message_bus.publish "/file-change", paths
  end

end
