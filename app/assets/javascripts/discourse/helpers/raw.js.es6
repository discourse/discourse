import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('raw', function(templateName, params) {
  var template = Discourse.__container__.lookup('template:' + templateName + '.raw');
  if (!template) {
    Ember.warn('Could not find raw template: ' + templateName);
    return;
  }
  return new Handlebars.SafeString(template(params));
});
