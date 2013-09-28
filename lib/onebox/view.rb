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
      if @layout
        render(url: record[:url], view: @view.to_html(record))
      else
        render(record)
      end
    end
  end
end
