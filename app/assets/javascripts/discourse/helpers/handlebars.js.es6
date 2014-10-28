Handlebars.registerHelper('handlebars', function(property, options) {

  var template = Em.TEMPLATES[property + ".raw"];
  var params = options.hash;

  if(params) {
    for(var prop in params){
      params[prop] = Em.Handlebars.get(this, params[prop]);
    }
  }

  return new Handlebars.SafeString(template(params));
});

Handlebars.registerHelper('get', function(property) {
  return Em.get(this, property);
});
