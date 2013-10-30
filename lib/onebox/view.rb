module Onebox
  class View < Mustache
    attr_reader :view
    attr_reader :cache

    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")

    def initialize(name, layout = false, cache = nil)
      @layout = layout
      if layout?
        @cache = cache
        @md5 = Digest::MD5.new
        @view = View.new(name)
      end
      self.template_name = if layout? then "_layout" else name end
    end

    def to_html(record)
      if cache.key?(checksum)
        cache.fetch(checksum)
      else
        cache.store(checksum, content(record))
      end
    end

    def layout?
      @layout
    end

    private

    def checksum(record)
      @checksum ||= @md5.hexdigest(content)
    end

    def content(record)
      @content ||= if layout? then render(details record) else render(record) end
    end

    def details(record)
      {
        link: record[:link],
        title: record[:title],
        badge: record[:badge],
        domain: record[:domain],
        subname: view.template_name,
        view: view.to_html(record)
      }
    end
  end
end
