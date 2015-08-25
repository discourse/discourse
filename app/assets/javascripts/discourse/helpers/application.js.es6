import registerUnbound from 'discourse/helpers/register-unbound';
import avatarTemplate from 'discourse/lib/avatar-template';
import { longDate, autoUpdatingRelativeAge, number } from 'discourse/lib/formatter';

const safe = Handlebars.SafeString;

Em.Handlebars.helper('bound-avatar', function(user, size, uploadId) {
  if (Em.isEmpty(user)) {
    return new safe("<div class='avatar-placeholder'></div>");
  }

  const username = Em.get(user, 'username');
  if (arguments.length < 4) { uploadId = Em.get(user, 'uploaded_avatar_id'); }
  const avatar = Em.get(user, 'avatar_template') || avatarTemplate(username, uploadId);

  return new safe(Discourse.Utilities.avatarImg({ size: size, avatarTemplate: avatar }));
}, 'username', 'uploaded_avatar_id', 'avatar_template');

/*
 * Used when we only have a template
 */
Em.Handlebars.helper('bound-avatar-template', function(at, size) {
  return new safe(Discourse.Utilities.avatarImg({ size: size, avatarTemplate: at }));
});

registerUnbound('raw-date', function(dt) {
  return longDate(new Date(dt));
});

registerUnbound('age-with-tooltip', function(dt) {
  return new safe(autoUpdatingRelativeAge(new Date(dt), {title: true}));
});

registerUnbound('number', function(orig, params) {
  orig = parseInt(orig, 10);
  if (isNaN(orig)) { orig = 0; }

  let title = orig;
  if (params.numberKey) {
    title = I18n.t(params.numberKey, { number: orig });
  }

  let classNames = 'number';
  if (params['class']) {
    classNames += ' ' + params['class'];
  }
  let result = "<span class='" + classNames + "'";

  // Round off the thousands to one decimal place
  const n = number(orig);
  if (n !== title) {
    result += " title='" + Handlebars.Utils.escapeExpression(title) + "'";
  }
  result += ">" + n + "</span>";

  return new safe(result);
});
