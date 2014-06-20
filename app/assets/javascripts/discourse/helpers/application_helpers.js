// helper function for dates
function daysSinceEpoch(dt) {
  // 1000 * 60 * 60 * 24 = days since epoch
  return dt.getTime() / 86400000;
}

/**
  Converts a date to a coldmap class

  @method cold-age-class
  @for Handlebars
**/
Handlebars.registerHelper('cold-age-class', function(property, options) {
  var dt = Em.Handlebars.get(this, property, options);

  if (!dt) { return 'age'; }

  // Show heat on age
  var nowDays = daysSinceEpoch(new Date()),
      epochDays = daysSinceEpoch(new Date(dt));
  if (nowDays - epochDays > 60) return 'age coldmap-high';
  if (nowDays - epochDays > 30) return 'age coldmap-med';
  if (nowDays - epochDays > 14) return 'age coldmap-low';

  return 'age';
});


/**
  Truncates long strings

  @method shorten
  @for Handlebars
**/
Handlebars.registerHelper('shorten', function(property, options) {
  return Ember.Handlebars.get(this, property, options).substring(0,35);
});

/**
  Produces a link to a topic

  @method topic-link
  @for Handlebars
**/
Handlebars.registerHelper('topic-link', function(property, options) {
  var topic = Ember.Handlebars.get(this, property, options),
      title = topic.get('fancy_title');
  return "<a href='" + topic.get('lastUnreadUrl') + "' class='title'>" + title + "</a>";
});


/**
  Produces a link to a category given a category object and helper options

  @method categoryLinkHTML
  @param {Discourse.Category} category to link to
  @param {Object} options standard from handlebars
**/
function categoryLinkHTML(category, options) {
  var categoryOptions = {};
  if (options.hash) {
    if (options.hash.allowUncategorized) { categoryOptions.allowUncategorized = true; }
    if (options.hash.showParent) { categoryOptions.showParent = true; }
    if (options.hash.onlyStripe) { categoryOptions.onlyStripe = true; }
    if (options.hash.link !== undefined) { categoryOptions.link = options.hash.link; }
    if (options.hash.extraClasses) { categoryOptions.extraClasses = options.hash.extraClasses; }
    if (options.hash.categories) {
      categoryOptions.categories = Em.Handlebars.get(this, options.hash.categories, options);
    }
  }
  return new Handlebars.SafeString(Discourse.HTML.categoryBadge(category, categoryOptions));
}

/**
  Produces a link to a category

  @method category-link
  @for Handlebars
**/
Handlebars.registerHelper('category-link', function(property, options) {
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});

Handlebars.registerHelper('category-link-raw', function(property, options) {
  return categoryLinkHTML(property, options);
});

Handlebars.registerHelper('category-badge', function(property, options) {
  options.hash.link = false;
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});


/**
  Produces a bound link to a category

  @method bound-category-link
  @for Handlebars
**/
Em.Handlebars.helper('bound-category-link', categoryLinkHTML);

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
  Shorten a URL for display by removing common components

  @method shortenUrl
  @for Handlebars
**/
Handlebars.registerHelper('shorten-url', function(property, options) {
  var url, matches;
  url = Ember.Handlebars.get(this, property, options);
  // Remove trailing slash if it's a top level URL
  matches = url.match(/\//g);
  if (matches && matches.length === 3) {
    url = url.replace(/\/$/, '');
  }
  url = url.replace(/^https?:\/\//, '');
  url = url.replace(/^www\./, '');
  return url.substring(0,80);
});

/**
  Show an avatar for a user, intelligently making use of available properties

  @method avatar
  @for Handlebars
**/
Handlebars.registerHelper('avatar', function(user, options) {
  if (typeof user === 'string') {
    user = Ember.Handlebars.get(this, user, options);
  }

  if (user) {
    var username = Em.get(user, 'username');
    if (!username) username = Em.get(user, options.hash.usernamePath);

    var title;
    if (!options.hash.ignoreTitle) {
      // first try to get a title
      title = Em.get(user, 'title');
      // if there was no title provided
      if (!title) {
        // try to retrieve a description
        var description = Em.get(user, 'description');
        // if a description has been provided
        if (description && description.length > 0) {
          // preprend the username before the description
          title = username + " - " + description;
        }
      }
    }

    // this is simply done to ensure we cache images correctly
    var uploadedAvatarId = Em.get(user, 'uploaded_avatar_id') || Em.get(user, 'user.uploaded_avatar_id');
    var avatarTemplate = Discourse.User.avatarTemplate(username,uploadedAvatarId);

    return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
      size: options.hash.imageSize,
      extraClasses: Em.get(user, 'extras') || options.hash.extraClasses,
      title: title || username,
      avatarTemplate: avatarTemplate
    }));
  } else {
    return '';
  }
});

/**
  Bound avatar helper.

  @method bound-avatar
  @for Handlebars
**/
Em.Handlebars.helper('bound-avatar', function(user, size, uploadId) {

  var username = Em.get(user, 'username');

  if(arguments.length < 4){
    uploadId = Em.get(user, 'uploaded_avatar_id');
  }

  var avatarTemplate = Discourse.User.avatarTemplate(username, uploadId);

  return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
    size: size,
    avatarTemplate: avatarTemplate
  }));
}, 'username', 'uploaded_avatar_id');

/*
 * Used when we only have a template
 */
Em.Handlebars.helper('bound-avatar-template', function(avatarTemplate, size) {
  return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
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
  return Discourse.Formatter.longDate(new Date(date));
});

/**
  Live refreshing age helper

  @method age
  @for Handlebars
**/
Handlebars.registerHelper('age', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt));
});

/**
  Live refreshing age helper, with a tooltip showing the date and time

  @method age-with-tooltip
  @for Handlebars
**/
Handlebars.registerHelper('age-with-tooltip', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt, {title: true}));
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

  return new Handlebars.SafeString(result);
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
    return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: leaveAgo}));
  }
});

Em.Handlebars.helper('bound-date', function(dt) {
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(new Date(dt), {format: 'medium', title: true }));
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
  return new Handlebars.SafeString(I18n.toHumanSize(size));
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
        return new Handlebars.SafeString("<span class='domain'>" + domain + "</span>");
      }
    }
  }
});

/**
  Renders a font-awesome icon with an optional i18n string as hidden text for
  screen readers.

  @method icon
  @for Handlebars
**/
Handlebars.registerHelper('icon', function(icon, options) {
  var labelKey, html;
  if (options.hash) { labelKey = options.hash.label; }
  html = "<i class='fa fa-" + icon + "'";
  if (labelKey) { html += " aria-hidden='true'"; }
  html += "></i>";
  if (labelKey) {
    html += "<span class='sr-only'>" + I18n.t(labelKey) + "</span>";
  }
  return new Handlebars.SafeString(html);
});
