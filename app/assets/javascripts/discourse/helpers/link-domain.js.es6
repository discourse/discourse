Handlebars.registerHelper('link-domain', function(property, options) {
  var link = Em.get(this, property, options);
  if (link) {
    var internal = Em.get(link, 'internal'),
        hasTitle = (!Em.isEmpty(Em.get(link, 'title')));
    if (hasTitle && !internal) {
      var domain = Em.get(link, 'domain');
      if (!Em.isEmpty(domain)) {
        var s = domain.split('.');
        domain = s[s.length-2] + "." + s[s.length-1];
        return new Handlebars.SafeString("<span class='domain'>" + domain + "</span>");
      }
    }
  }
});
