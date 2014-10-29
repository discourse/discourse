Handlebars.registerHelper('raw', function(property, options) {

  var template = Em.TEMPLATES[property + ".raw"];
  var params = options.hash;

  if(params) {
    for(var prop in params){
      if(options.hashTypes[prop] === "ID") {
        params[prop] = Em.Handlebars.get(this, params[prop], options);
      }
    }
  }

  return new Handlebars.SafeString(template(params));
});
