import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('link-domain', function(link) {
  if (link) {
    const hasTitle = (!Ember.isEmpty(Em.get(link, 'title')));

    if (hasTitle) {
      let domain = Ember.get(link, 'domain');
      if (!Ember.isEmpty(domain)) {
        const s = domain.split('.');
        domain = s[s.length-2] + "." + s[s.length-1];
        return new Handlebars.SafeString("<span class='domain'>" + domain + "</span>");
      }
    }
  }
});
