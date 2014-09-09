var safe = Handlebars.SafeString;

/**
  Produces a link to a route with support for i18n on the title

  @method titled-link-to
  @for Handlebars
**/
Handlebars.registerHelper('titled-link-to', function(name, object) {
  var options = [].slice.call(arguments, -1)[0];
  if (options.hash.titleKey) {
    options.hash.title = I18n.t(options.hash.titleKey);
  }
  if (arguments.length === 3) {
    return Ember.Handlebars.helpers['link-to'].call(this, name, object, options);
  } else {
    return Ember.Handlebars.helpers['link-to'].call(this, name, options);
  }
});

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
  Nicely format a bound date without returning HTML

  @method bound-raw-date
  @for Handlebars
**/
Em.Handlebars.helper('bound-raw-date', function (date) {
  return Discourse.Formatter.longDateNoYear(new Date(date));
});

/**
  Live refreshing age helper

  @method age
  @for Handlebars
**/
Handlebars.registerHelper('age', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new safe(Discourse.Formatter.autoUpdatingRelativeAge(dt));
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

/**
  Display logic for numbers.

  @method number
  @for Handlebars
**/
Handlebars.registerHelper('number', function(property, options) {

  var orig = parseInt(Ember.Handlebars.get(this, property, options), 10);
  if (isNaN(orig)) { orig = 0; }

  var title = orig;
  if (options.hash.numberKey) {
    title = I18n.t(options.hash.numberKey, { number: orig });
  }

  var classNames = 'number';
  if (options.hash['class']) {
    classNames += ' ' + Ember.Handlebars.get(this, options.hash['class'], options);
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

/**
  Display logic for dates. It is unbound in Ember but will use jQuery to
  update the dates on a regular interval.

  @method date
  @for Handlebars
**/
Handlebars.registerHelper('date', function(property, options) {
  var leaveAgo;
  if (property.hash) {
    if (property.hash.leaveAgo) {
      leaveAgo = property.hash.leaveAgo === "true";
    }
    if (property.hash.path) {
      property = property.hash.path;
    }
  }

  var val = Ember.Handlebars.get(this, property, options);
  if (val) {
    var date = new Date(val);
    return new safe(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: leaveAgo}));
  }
});

Em.Handlebars.helper('bound-date', function(dt) {
  return new safe(Discourse.Formatter.autoUpdatingRelativeAge(new Date(dt), {format: 'medium', title: true }));
});

/**
  Look for custom html content using `Discourse.HTML`. If none exists, look for a template
  to render with that name.

  @method custom-html
  @for Handlebars
**/
Handlebars.registerHelper('custom-html', function(name, contextString, options) {
  var html = Discourse.HTML.getCustomHTML(name);
  if (html) { return html; }

  var container = (options || contextString).data.keywords.controller.container;

  if (container.lookup('template:' + name)) {
    return Ember.Handlebars.helpers.partial.apply(this, arguments);
  }
});

Em.Handlebars.helper('human-size', function(size) {
  return new safe(I18n.toHumanSize(size));
});

/**
  Renders the domain for a link if it's not internal and has a title.

  @method link-domain
  @for Handlebars
**/
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
        return new safe("<span class='domain'>" + domain + "</span>");
      }
    }
  }
});
