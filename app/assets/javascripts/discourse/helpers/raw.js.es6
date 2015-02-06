import registerUnbound from 'discourse/helpers/register-unbound';

function renderRaw(template, templateName, params) {
  params.parent = params.parent || this;

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

  return renderRaw.call(this, template, templateName, params);
});

export { renderRaw };
