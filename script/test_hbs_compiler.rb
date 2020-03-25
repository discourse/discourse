# frozen_string_literal: true

template = <<~HBS
  {{attach widget="wat" attrs=(hash test="abc" text=(i18n "hello" count=attrs.wat))}}
  {{action-link action="undo" className="undo" text=(i18n (concat "post.actions.undo." attrs.action))}}
  {{actions-summary-item attrs=as}}
  {{attach widget="actions-summary-item" attrs=as}}
  {{testing value="hello"}}
HBS

ctx = MiniRacer::Context.new(timeout: 15000)
ctx.eval("var self = this; #{File.read("#{Rails.root}/vendor/assets/javascripts/babel.js")}")
ctx.eval(File.read(Ember::Source.bundled_path_for('ember-template-compiler.js')))
ctx.eval("module = {}; exports = {};")
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

puts ctx.eval("exports.compile(#{js_source})")
