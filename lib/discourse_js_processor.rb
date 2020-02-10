# frozen_string_literal: true
class DiscourseJsProcessor

  def self.call(input)

    root_path = input[:load_path] || ''
    logical_path = (input[:filename] || '').sub(root_path, '').gsub(/\.(js|es6).*$/, '').sub(/^\//, '')
    data = input[:data]

    if should_transpile?(input)
      data = transpile(data, root_path, logical_path)
    end

    # add sourceURL until we can do proper source maps
    unless Rails.env.production?
      data = "eval(#{data.inspect} + \"\\n//# sourceURL=#{logical_path}\");\n"
    end

    { data: data }
  end

  def self.transpile(data, root_path, logical_path)
    template = Tilt::ES6ModuleTranspilerTemplate.new {}
    template.skip_module = true if skip_module?(data)
    template.module_transpile(data, root_path, logical_path)
  end

  def self.should_transpile?(input)
    filename = input[:filename] || ''
    # es6 is always transpiled
    return true if filename.end_with?(".es6") || filename.end_with?(".es6.erb")

    # For .js check the path...
    return false unless filename.end_with?(".js") || filename.end_with?(".js.erb")

    relative_path = filename.sub(Rails.root.to_s, '').sub(/^\/*/, '')
    relative_path.start_with?("app/assets/javascripts/discourse/")
  end

  def self.skip_module?(data)
    !!(data.present? && data =~ /^\/\/ discourse-skip-module$/)
  end

end
