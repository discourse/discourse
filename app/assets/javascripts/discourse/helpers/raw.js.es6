import registerUnbound from 'discourse/helpers/register-unbound';

var viewCache = {};

registerUnbound('raw', function(templateName, params) {
  var template = Discourse.__container__.lookup('template:' + templateName + '.raw');
  if (!template) {
    Ember.warn('Could not find raw template: ' + templateName);
    return;
  }
  if(!params.parent) {
    params.parent = this;
  }

  if(!params.view) {
    var cached = viewCache[templateName];
    if(cached){
      params.view = cached === "X" ? undefined : cached.create(params);
    } else {
      var split = templateName.split("/");
      var last = split[split.length-1];
      var name = "discourse/views/" + last;

      if(hasModule(name)){
        viewCache[templateName] = require(name).default;
        params.view = viewCache[templateName].create(params);
      } else {
        viewCache[templateName] = "X";
      }
    }
  }

  return new Handlebars.SafeString(template(params));
});
