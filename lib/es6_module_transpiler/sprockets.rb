require 'sprockets'

Sprockets.register_mime_type 'application/ecmascript6', extensions: ['.es6', '.js.es6', '.js.no-module.es6'], charset: :unicode
Sprockets.register_transformer 'application/ecmascript6', 'application/javascript', Tilt::ES6ModuleTranspilerTemplate
