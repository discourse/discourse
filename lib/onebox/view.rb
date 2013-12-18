module Onebox
  class View < Mustache
    attr_reader :record

    self.template_path = Onebox.options.load_paths.last

    def initialize(name, record)
      @record = record
      self.template_name = name
    end

    def to_html
      render(record)
    end
  end
end
