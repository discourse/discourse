var safe = Handlebars.SafeString;

// TODO: Remove me when ES6ified
var registerUnbound = require('discourse/helpers/register-unbound', null, null, true).default;

/**
  Bound avatar helper.

  @method bound-avatar
  @for Handlebars
**/
Em.Handlebars.helper('bound-avatar', function(user, size, uploadId) {
  if (Em.isEmpty(user)) {
    return new safe("<div class='avatar-placeholder'></div>");
  }
  var username = Em.get(user, 'username');

  if(arguments.length < 4){
    uploadId = Em.get(user, 'uploaded_avatar_id');
  }

  var avatarTemplate = Discourse.User.avatarTemplate(username, uploadId);

  return new safe(Discourse.Utilities.avatarImg({
    size: size,
    avatarTemplate: avatarTemplate
  }));
}, 'username', 'uploaded_avatar_id');

/*
 * Used when we only have a template
 */
Em.Handlebars.helper('bound-avatar-template', function(avatarTemplate, size) {
  return new safe(Discourse.Utilities.avatarImg({
    size: size,
    avatarTemplate: avatarTemplate
  }));
});

/**
  Nicely format a date without binding or returning HTML

  @method raw-date
  @for Handlebars
**/
Handlebars.registerHelper('raw-date', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return Discourse.Formatter.longDate(dt);
});

/**
  Live refreshing age helper, with a tooltip showing the date and time

  @method age-with-tooltip
  @for Handlebars
**/
Handlebars.registerHelper('age-with-tooltip', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new safe(Discourse.Formatter.autoUpdatingRelativeAge(dt, {title: true}));
});

registerUnbound('number', function(orig, params) {
  orig = parseInt(orig, 10);
  if (isNaN(orig)) { orig = 0; }

  var title = orig;
  if (params.numberKey) {
    title = I18n.t(params.numberKey, { number: orig });
  }

  var classNames = 'number';
  if (params['class']) {
    classNames += ' ' + params['class'];
  }
  var result = "<span class='" + classNames + "'";

  // Round off the thousands to one decimal place
  var n = Discourse.Formatter.number(orig);
  if (n !== title) {
    result += " title='" + Handlebars.Utils.escapeExpression(title) + "'";
  }
  result += ">" + n + "</span>";

  return new safe(result);
});
