class SourceURL < Tilt::Template
  self.default_mime_type = 'application/javascript'

  def prepare
  end

  def evaluate(scope, locals, &block)
    code = "eval("
    code << data.inspect
    code << " + \"\\n//# sourceURL=#{scope.logical_path}\""
    code << ");\n"
    code
  end
end
