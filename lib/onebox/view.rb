module Onebox
  class View < Mustache
    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")

    def initialize(name, record, layout = false)
      @layout = layout
      self.template_name = unless @layout then name else "_layout" end
      @record = record
      @view = View.new(name, record) if @layout
    end

    def to_html
      if @layout
        render(url: @record[:url], view: @view.to_html)
      else
        render(@record)
      end
    end
  end
end
