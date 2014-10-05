require 'sprockets'

Sprockets.register_engine '.es6', Tilt::ES6ModuleTranspilerTemplate
