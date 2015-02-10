import registerUnbound from 'discourse/helpers/register-unbound';

function renderRaw(ctx, template, templateName, params) {
  params.parent = params.parent || ctx;

  if (!params.view) {
    var viewClass = Discourse.__container__.lookupFactory('view:' + templateName);
    if (viewClass) {
      params.view = viewClass.create(params);
    }
  }

  return new Handlebars.SafeString(template(params));
}

registerUnbound('raw', function(templateName, params) {
  var template = Discourse.__container__.lookup('template:' + templateName + '.raw');
  if (!template) {
    Ember.warn('Could not find raw template: ' + templateName);
    return;
  }

  return renderRaw(this, template, templateName, params);
});
