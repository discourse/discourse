import registerUnbound from 'discourse/helpers/register-unbound';
import { longDate, autoUpdatingRelativeAge, number } from 'discourse/lib/formatter';

const safe = Handlebars.SafeString;

Em.Handlebars.helper('bound-avatar', (user, size) => {
  if (Em.isEmpty(user)) {
    return new safe("<div class='avatar-placeholder'></div>");
  }

  const avatar = Em.get(user, 'avatar_template');
  return new safe(Discourse.Utilities.avatarImg({ size: size, avatarTemplate: avatar }));
}, 'username', 'avatar_template');

/*
 * Used when we only have a template
 */
Em.Handlebars.helper('bound-avatar-template', (at, size) => {
  return new safe(Discourse.Utilities.avatarImg({ size: size, avatarTemplate: at }));
});

registerUnbound('raw-date', dt => longDate(new Date(dt)));

registerUnbound('age-with-tooltip', dt => new safe(autoUpdatingRelativeAge(new Date(dt), {title: true})));

registerUnbound('number', (orig, params) => {
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
