require 'rails/generators/named_base'

class PluginGenerator < Rails::Generators::NamedBase
  desc 'This generator creates a Discourse plugin skeleton'

  source_root File.expand_path('templates', __dir__)

  class_option :author, type: :string, desc: "Plugin author", required: true
  class_option :stylesheet, type: :boolean, desc: "Generate Stylesheet", default: true
  class_option :javascript, type: :boolean, desc: "Generate Javascript initializer", default: true
  class_option :scheduled_job, type: :boolean, desc: "Generate Stylesheet", default: false

  def create_scheduled_job_file
    return unless @options['scheduled_job']

    path = File.join('plugins', dasherized_name, 'jobs/scheduled', "check_#{underscored_name}.rb")
    template 'scheduled_job.rb.erb', path
  end

  def create_readme_file
    template 'README.md.erb', File.join('plugins', dasherized_name, "README.md")
  end

  def create_license_file
    template 'LICENSE.erb', File.join('plugins', dasherized_name, "LICENSE")
  end

  def create_plugin_file
    template 'plugin.rb.erb', File.join('plugins', dasherized_name, "plugin.rb")
  end

  def create_stylesheet_file
    return unless @options['stylesheet']

    template 'stylesheet.scss.erb', File.join('plugins', dasherized_name, 'assets/stylesheets/common', "#{dasherized_name}.scss")
  end

  def create_javascript_file
    return unless @options['javascript']

    template 'javascript.es6.erb', File.join('plugins', dasherized_name, 'assets/javascripts/initializers', "#{dasherized_name}.es6")
  end

  def create_gitignore_entry
    plugin_entry = "!/plugins/#{dasherized_name}"

    unless File.readlines(".gitignore").grep(/#{plugin_entry}/).size > 0
      open('.gitignore', 'a') { |f| f.puts "\n#{plugin_entry}" }
    end
  end

  def underscored_name
    name.underscore
  end

  def dasherized_name
    underscored_name.dasherize
  end

  def classified_name
    name.tableize.classify
  end
end
