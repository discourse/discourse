# frozen_string_literal: true

# Eventually we aim to move away from using Barber to precompile assets.
# These overrides unblock us moving to more recent ember versions in the meantime

module BarberEmberPrecompilerFreedomPatch
  # Use the template compiler JS from node_modules
  def ember_template_precompiler
    @ember ||= File.new("app/assets/javascripts/node_modules/ember-source/dist/ember-template-compiler.js")
  end

  # Apply a couple of extra shims for more recent ember-template-compilers
  def source_fixes
    shims = super

    shims << <<~JS
      module = {exports:{}}

      console = {
        log: function(){},
        warn: function(){},
        error: function(){}
      };
    JS

    shims
  end

  # Recent ember-template-compilers fail if `option` is null
  def compile(template, options = nil)
    options = {} if options.nil?
    super(template, options)
  end
end

Barber::Ember::Precompiler.prepend(BarberEmberPrecompilerFreedomPatch)
