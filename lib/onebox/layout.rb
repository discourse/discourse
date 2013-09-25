module Onebox
  class Layout < Mustache
    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")
    self.template_name = "_layout"

    def initialize(name, record)
      @name = name
      @record = record
      @url = record[:url]
    end

    def to_html
      render
    end

    private

    def view
      File.read(template_path)
    end

    def view_path
      File.join(root, "templates", "#{@name}.handlebars")
    end

    def layout
      File.read(layout_path)
    end

    def layout_path
      File.join(root, "templates", "_layout.handlebars")
    end
  end
end
