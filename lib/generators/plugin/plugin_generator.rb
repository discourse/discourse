# frozen_string_literal: true

require 'rails/generators/named_base'

class PluginGenerator < Rails::Generators::NamedBase
  attr_writer :about
  attr_writer :github_username

  desc 'This generator creates a Discourse plugin skeleton'

  source_root File.expand_path('templates', __dir__)

  class_option :no_license, type: :boolean, desc: "No license", default: false

  def create_plugin
    @about ||= ask("What is the purpose of your plugin?")
    @github_username ||= ask("Github username?")

    readme_file
    routes_file
    engine_file
    plugin_file
    controller_file
    license_file
    stylesheet_file
    javascript_file
    settings_file
    locales_file
  end

  def controller_file
    template 'plugin_controller.rb.erb', File.join('plugins', dasherized_name, "app/controllers/#{underscored_name}/#{underscored_name}_controller.rb")
    template 'controller.rb.erb', File.join('plugins', dasherized_name, "app/controllers/#{underscored_name}/actions_controller.rb")
    template 'controller_spec.rb.erb', File.join('plugins', dasherized_name, "spec/requests/actions_controller_spec.rb")
  end

  def readme_file
    template 'README.md.erb', File.join('plugins', dasherized_name, "README.md")
  end

  def license_file
    return if @options['no_license']

    template 'LICENSE.erb', File.join('plugins', dasherized_name, "LICENSE")
  end

  def engine_file
    template 'engine.rb.erb', File.join('plugins', dasherized_name, "lib", dasherized_name, "engine.rb")
  end

  def routes_file
    template 'routes.rb.erb', File.join('plugins', dasherized_name, "config", "routes.rb")
    template 'route_constraint.rb.erb', File.join('plugins', dasherized_name, "lib", "#{underscored_name}_constraint.rb")
  end

  def plugin_file
    template 'plugin.rb.erb', File.join('plugins', dasherized_name, "plugin.rb")
  end

  def stylesheet_file
    template 'stylesheet.scss.erb', File.join('plugins', dasherized_name, 'assets/stylesheets/common', "#{dasherized_name}.scss")
    template 'stylesheet.scss.erb', File.join('plugins', dasherized_name, 'assets/stylesheets/desktop', "#{dasherized_name}.scss")
    template 'stylesheet.scss.erb', File.join('plugins', dasherized_name, 'assets/stylesheets/mobile', "#{dasherized_name}.scss")
  end

  def javascript_file
    template 'acceptance-test.js.es6.erb', File.join('plugins', dasherized_name, "test/javascripts/acceptance", "#{dasherized_name}-test.js.es6")
    template 'javascript.js.es6.erb', File.join('plugins', dasherized_name, 'assets/javascripts/initializers', "#{dasherized_name}.js.es6")
    template 'route-map.js.es6.erb', File.join('plugins', dasherized_name, 'assets/javascripts/discourse', "#{dasherized_name}-route-map.js.es6")

    folder = 'assets/javascripts/discourse/templates'
    template "#{folder}/template.hbs.erb", path(folder, "actions.hbs")
    template "#{folder}/template-show.hbs.erb", path(folder, "actions-show.hbs")
    template "#{folder}/template-index.hbs.erb", path(folder, "actions-index.hbs")

    folder = 'assets/javascripts/discourse/routes'
    template "#{folder}/route.js.es6.erb", path(folder, "#{dasherized_name}-actions.js.es6")
    template "#{folder}/route-show.js.es6.erb", path(folder, "#{dasherized_name}-actions-show.js.es6")
    template "#{folder}/route-index.js.es6.erb", path(folder, "#{dasherized_name}-actions-index.js.es6")

    folder = 'assets/javascripts/discourse/controllers'
    template "#{folder}/controller.js.es6.erb", path(folder, "actions.js.es6")
    template "#{folder}/controller-show.js.es6.erb", path(folder, "actions-show.js.es6")
    template "#{folder}/controller-index.js.es6.erb", path(folder, "actions-index.js.es6")

    folder = 'assets/javascripts/discourse/models'
    template "#{folder}/model.js.es6.erb", path(folder, "action.js.es6")

    folder = 'assets/javascripts/discourse/adapters'
    template "#{folder}/adapter.js.es6.erb", path(folder, "action.js.es6")
  end

  def settings_file
    template 'settings.yml.erb', File.join('plugins', dasherized_name, 'config', 'settings.yml')
  end

  def locales_file
    template 'client.en.yml.erb', path('config/locales/client.en.yml')
    template 'server.en.yml.erb', File.join('plugins', dasherized_name, 'config/locales', 'server.en.yml')
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

  def path(*args)
    File.join('plugins', dasherized_name, args)
  end
end
