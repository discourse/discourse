import { registerUnbound } from 'discourse/lib/helpers';

registerUnbound('i18n', function(key, params) {
  return I18n.t(key, params);
});

registerUnbound('replace-emoji', function(text) {
  return new Handlebars.SafeString(Discourse.Emoji.unescape(text));
});
