import { registerUnbound } from 'discourse/lib/helpers';

registerUnbound('cook-text', function(text) {
  return new Handlebars.SafeString(Discourse.Markdown.cook(text, {sanitize: true}));
});

