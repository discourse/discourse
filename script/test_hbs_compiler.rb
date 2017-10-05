template = <<~HBS
  {{attach widget="widget-name" attrs=attrs}}
  {{a}}
  {{{htmlValue}}}
  {{#if state.category}}
    {{attach widget="category-display" attrs=(hash category=state.category someNumber=123 someString="wat")}}
  {{/if}}
  {{#each transformed.something as |s|}}
    {{s.wat}}
  {{/each}}

  {{attach widget=settings.widgetName}}

  {{#unless settings.hello}}
    XYZ
  {{/unless}}
HBS

ctx = MiniRacer::Context.new(timeout: 15000)
ctx.eval("var self = this; #{File.read("#{Rails.root}/vendor/assets/javascripts/babel.js")}")
ctx.eval(File.read(Ember::Source.bundled_path_for('ember-template-compiler.js')))
ctx.eval("module = {}; exports = {};");
ctx.attach("rails.logger.info", proc { |err| puts(err.to_s) })
ctx.attach("rails.logger.error", proc { |err| puts(err.to_s) })
ctx.eval <<JS
console = {
  prefix: "",
  log: function(msg){ rails.logger.info(console.prefix + msg); },
  error: function(msg){ rails.logger.error(console.prefix + msg); }
}

JS
source = File.read("#{Rails.root}/lib/javascripts/widget-hbs-compiler.js.es6")
ctx.eval(source)

js_source = ::JSON.generate(template, quirks_mode: true)

puts ctx.eval("exports.compile(#{js_source})");
