module Onebox
  class View < Mustache
    attr_reader :view

    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")

    def initialize(name, layout = false)
      @layout = layout
      self.template_name = if layout? then "_layout" else name end
    end

    def to_html(record)
      if layout? then render(details record) else render(record) end
    end

    def layout?
      @layout
    end

    private

    def details(record)
      {
        link: record[:link],
        title: record[:title],
        badge: record[:badge],
        domain: record[:domain],
        view: subview(record)
      }
    end
  end
end
