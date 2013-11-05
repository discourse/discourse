module Onebox
  class View < Mustache
    attr_reader :record

    self.template_path = File.join(Gem::Specification.find_by_name("onebox").gem_dir, "templates")

    def initialize(name, record)
      @record = record
      self.template_name = name
    end

    def to_html
      render(record)
    end
  end
end
