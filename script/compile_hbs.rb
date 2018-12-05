ctx = MiniRacer::Context.new(timeout: 15000)
ctx.eval("var self = this; #{File.read("#{Rails.root}/vendor/assets/javascripts/babel.js")}")
ctx.eval(File.read(Ember::Source.bundled_path_for('ember-template-compiler.js')))
ctx.eval("module = {}; exports = {};")
ctx.attach("rails.logger.info", proc { |err| puts(">> #{err.to_s}") })
ctx.attach("rails.logger.error", proc { |err| puts(">> #{err.to_s}") })
ctx.eval <<JS
console = {
  prefix: "",
  log: function(msg){ rails.logger.info(console.prefix + msg); },
  error: function(msg){ rails.logger.error(console.prefix + msg); }
}

JS
source = File.read("#{Rails.root}/lib/javascripts/widget-hbs-compiler.js.es6")
js_source = ::JSON.generate(source, quirks_mode: true)
js = ctx.eval("Babel.transform(#{js_source}, { ast: false, plugins: ['check-es2015-constants', 'transform-es2015-arrow-functions', 'transform-es2015-block-scoped-functions', 'transform-es2015-block-scoping', 'transform-es2015-classes', 'transform-es2015-computed-properties', 'transform-es2015-destructuring', 'transform-es2015-duplicate-keys', 'transform-es2015-for-of', 'transform-es2015-function-name', 'transform-es2015-literals', 'transform-es2015-object-super', 'transform-es2015-parameters', 'transform-es2015-shorthand-properties', 'transform-es2015-spread', 'transform-es2015-sticky-regex', 'transform-es2015-template-literals', 'transform-es2015-typeof-symbol', 'transform-es2015-unicode-regex'] }).code")
ctx.eval(js)

if ARGV[0].present?
  source = File.read(ARGV[0])
  js_source = ::JSON.generate(source, quirks_mode: true)
  puts ctx.eval("exports.compile(#{js_source})")
end
