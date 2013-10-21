module Onebox
  class View < Mustache
    attr_reader :view

    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")

    def initialize(name, layout = false)
      @layout = layout
      self.template_name = unless @layout then name else "_layout" end
      @view = View.new(name) if @layout
    end

    def to_html(record)
      render(if @layout then details(record) else render(record) end)
    end

    private

    def subview(record)
      @view.to_html(record)
    end

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
