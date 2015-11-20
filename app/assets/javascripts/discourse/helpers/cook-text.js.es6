import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('cook-text', function(text) {
  return new Handlebars.SafeString(Discourse.Markdown.cook(text, {sanitize: true}));
});

