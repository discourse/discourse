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
    "#{data.rstrip} //# sourceURL=#{scope.logical_path}\n\n"
  end
end
