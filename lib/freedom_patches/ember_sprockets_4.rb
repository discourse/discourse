# frozen_string_literal: true

# One of the initializers in `discourse-ember-rails/lib/ember_rails.rb` tries to set
# the ember template compiler path based on a call to `Sprockets::Environment#resolve`
# which started returning an array in Sprockets 4.
# This doesn't seem to be needed - it was setting to the existing value, so we can just ignore it.
Ember::Handlebars::Template.singleton_class.prepend(Module.new do
  def setup_ember_template_compiler(path)
    return if path.is_a? Array
    super
  end
end)
