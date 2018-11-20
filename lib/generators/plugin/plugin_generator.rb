require 'rails/generators/named_base'

class PluginGenerator < Rails::Generators::NamedBase
  attr_writer :github_username

  desc 'This generator creates a Discourse plugin skeleton'

  source_root File.expand_path('templates', __dir__)

  class_option :controller, type: :boolean, desc: "Generate controller", default: true
  class_option :spec, type: :boolean, desc: "Generate spec", default: true
  class_option :acceptance, type: :boolean, desc: "Generate acceptance test", default: true
  class_option :stylesheet, type: :boolean, desc: "Generate Stylesheet", default: true
  class_option :javascript, type: :boolean, desc: "Generate Javascript initializer", default: true
  class_option :scheduled_job, type: :boolean, desc: "Generate scheduled job", default: false
  class_option :help, type: :boolean, desc: "Adds help comments in generated files", default: true

  def create_acceptance_file
    return unless @options['acceptance']

    template 'acceptance-test.js.es6.erb', File.join('plugins', dasherized_name, "test/javascripts/acceptance", "#{dasherized_name}-test.js.es6")
  end

  def create_spec_file
    return if !@options['spec'] || !@options['controller']

    template 'controller_spec.rb.erb', File.join('plugins', dasherized_name, "spec/requests/actions_controller_spec.rb")
  end

  def create_scheduled_job_file
    return unless @options['scheduled_job']

    path = File.join('plugins', dasherized_name, 'jobs/scheduled', "check_#{underscored_name}.rb")
    template 'scheduled_job.rb.erb', path
  end

  def create_readme_file
    ensure_github_username

    template 'README.md.erb', File.join('plugins', dasherized_name, "README.md")
  end

  def create_license_file
    ensure_github_username

    template 'LICENSE.erb', File.join('plugins', dasherized_name, "LICENSE")
  end

  def create_plugin_file
    ensure_github_username

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

  def create_settings_file
    template 'settings.yml.erb', File.join('plugins', dasherized_name, 'config', 'settings.yml')
  end

  def create_locales_file
    template 'client.en.yml.erb', File.join('plugins', dasherized_name, 'config/locales', 'client.en.yml')
    template 'server.en.yml.erb', File.join('plugins', dasherized_name, 'config/locales', 'server.en.yml')
  end

  def create_gitignore_entry
    plugin_entry = "!/plugins/#{dasherized_name}"

    unless File.readlines(".gitignore").grep(/#{plugin_entry}/).size > 0
      open('.gitignore', 'a') { |f| f.puts "\n#{plugin_entry}" }
    end
  end

  def ensure_github_username
    @github_username ||= ask("Github username?")
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
