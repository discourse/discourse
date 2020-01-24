# frozen_string_literal: true

class SourceURL < Tilt::Template
  self.default_mime_type = 'application/javascript'

  def self.call(input)
    filename = input[:filename]
    source = input[:data]
    context = input[:environment].context_class.new(input)

    result = new(filename) { source }.render(context)
    context.metadata.merge(data: result)
  end

  def prepare
  end

  def evaluate(scope, locals, &block)
    code = +"eval("
    code << data.inspect
    code << " + \"\\n//# sourceURL=#{scope.logical_path}\""
    code << ");\n"
  end
end
