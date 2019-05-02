# frozen_string_literal: true

require 'es6_module_transpiler/rails/version'
require 'es6_module_transpiler/tilt'
require 'es6_module_transpiler/sprockets'

module ES6ModuleTranspiler
  def self.compile_to
    @compile_to || :amd
  end

  def self.compile_to=(target)
    @compile_to = target
  end

  def self.transform=(transform)
    @transform = transform
  end

  def self.transform
    @transform
  end

  def self.compiler_options
    @compiler_options ||= {}
  end
end
