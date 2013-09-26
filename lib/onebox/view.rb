module Onebox
  class View < Mustache
    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")
    self.template_name = "_layout"

    def initialize(name, record)
      @name = name
      @record = record
      @url = record[:url]
    end

    def to_html
      render(onebox: @name, url: @url)
    end
  end
end
