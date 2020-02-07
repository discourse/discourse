# frozen_string_literal: true
class DiscourseJsProcessor
  def self.call(input)
    { data: should_transpile?(input[:filename]) ? transpile(input) : input[:data] }
  end

  def self.transpile(input)
    root_path = input[:load_path] || ''
    logical_path = (input[:filename] || '').sub(root_path, '').gsub(/\.(js|es6).*$/, '').sub(/^\//, '')
    source = input[:data]

    template = Tilt::ES6ModuleTranspilerTemplate.new {}
    template.skip_module = true if skip_module?(input[:data])
    template.module_transpile(source, root_path, logical_path)
  end

  def self.should_transpile?(filename)
    filename ||= ''
    filename.end_with?(".es6") || filename.end_with?(".es6.erb")
  end

  def self.skip_module?(data)
    !!(data.present? && data =~ /^\/\/ discourse-skip-module$/)
  end

end
