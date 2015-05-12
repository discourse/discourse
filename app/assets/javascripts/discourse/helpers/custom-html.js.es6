Ember.HTMLBars._registerHelper('custom-html', function(params, hash, options, env) {
  const name = params[0];
  const html = Discourse.HTML.getCustomHTML(name);
  if (html) { return html; }

  const contextString = params[1];
  const container = (env || contextString).data.view.container;
  if (container.lookup('template:' + name)) {
    return env.helpers.partial.helperFunction.apply(this, arguments);
  }
});
