/**
  Breaks up a long string

  @method breakUp
  @for Handlebars
**/
Handlebars.registerHelper('breakUp', function(property, options) {
  var prop, result, tokens;
  prop = Ember.Handlebars.get(this, property, options);
  if (!prop) return "";

  return Discourse.Formatter.breakUp(prop, 13);
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

  @method topicLink
  @for Handlebars
**/
Handlebars.registerHelper('topicLink', function(property, options) {
  var topic = Ember.Handlebars.get(this, property, options),
      title = topic.get('fancy_title') || topic.get('title');
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
    if (options.hash.allowUncategorized) {
      categoryOptions.allowUncategorized = true;
    }
    if (options.hash.categories) {
      categoryOptions.categories = Em.Handlebars.get(this, options.hash.categories, options);
    }
  }
  return new Handlebars.SafeString(Discourse.HTML.categoryLink(category, categoryOptions));
}

/**
  Produces a link to a category

  @method categoryLink
  @for Handlebars
**/
Handlebars.registerHelper('categoryLink', function(property, options) {
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});

/**
  Produces a bound link to a category

  @method boundCategoryLink
  @for Handlebars
**/
Ember.Handlebars.registerBoundHelper('boundCategoryLink', categoryLinkHTML);

/**
  Produces a link to a route with support for i18n on the title

  @method titledLinkTo
  @for Handlebars
**/
Handlebars.registerHelper('titledLinkTo', function(name, object) {
  var options = [].slice.call(arguments, -1)[0];
  if (options.hash.titleKey) {
    options.hash.title = I18n.t(options.hash.titleKey);
  }
  if (arguments.length === 3) {
    return Ember.Handlebars.helpers.linkTo.call(this, name, object, options);
  } else {
    return Ember.Handlebars.helpers.linkTo.call(this, name, options);
  }
});

/**
  Shorten a URL for display by removing common components

  @method shortenUrl
  @for Handlebars
**/
Handlebars.registerHelper('shortenUrl', function(property, options) {
  var url;
  url = Ember.Handlebars.get(this, property, options);
  // Remove trailing slash if it's a top level URL
  if (url.match(/\//g).length === 3) {
    url = url.replace(/\/$/, '');
  }
  url = url.replace(/^https?:\/\//, '');
  url = url.replace(/^www\./, '');
  return url.substring(0,80);
});

/**
  Display a property in lower case

  @method lower
  @for Handlebars
**/
Handlebars.registerHelper('lower', function(property, options) {
  var o;
  o = Ember.Handlebars.get(this, property, options);
  if (o && typeof o === 'string') {
    return o.toLowerCase();
  } else {
    return "";
  }
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

    var avatarTemplate;
    var template = options.hash.template;
    if (template && template !== 'avatar_template') {
      avatarTemplate = Em.get(user, template);
      if (!avatarTemplate) avatarTemplate = Em.get(user, 'user.' + template);
    }

    if (!avatarTemplate) avatarTemplate = Em.get(user, 'avatar_template');
    if (!avatarTemplate) avatarTemplate = Em.get(user, 'user.avatar_template');

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
  Will rerender whenever the "avatar_template" changes.

  @method boundAvatar
  @for Handlebars
**/
Ember.Handlebars.registerBoundHelper('boundAvatar', function(user, options) {
  return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
    size: options.hash.imageSize,
    avatarTemplate: Em.get(user, options.hash.template || 'avatar_template')
  }));
}, 'avatar_template', 'uploaded_avatar_template', 'gravatar_template');

/**
  Nicely format a date without a binding since the date doesn't need to change.

  @method unboundDate
  @for Handlebars
**/
Handlebars.registerHelper('unboundDate', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return Discourse.Formatter.longDate(dt);
});

/**
  Live refreshing age helper

  @method unboundDate
  @for Handlebars
**/
Handlebars.registerHelper('unboundAge', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt));
});

/**
  Live refreshing age helper, with a tooltip showing the date and time

  @method unboundAgeWithTooltip
  @for Handlebars
**/
Handlebars.registerHelper('unboundAgeWithTooltip', function(property, options) {
  var dt = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(dt, {title: true}));
});

/**
  Display a date related to an edit of a post

  @method editDate
  @for Handlebars
**/
Handlebars.registerHelper('editDate', function(property, options) {
  // autoupdating this is going to be painful
  var date = new Date(Ember.Handlebars.get(this, property, options));
  return new Handlebars.SafeString(Discourse.Formatter.autoUpdatingRelativeAge(date, {format: 'medium', title: true, leaveAgo: true, wrapInSpan: false}));
});

/**
  Displays a percentile based on a `percent_rank` field

  @method percentile
  @for Ember.Handlebars
**/
Ember.Handlebars.registerHelper('percentile', function(property, options) {
  var percentile = Ember.Handlebars.get(this, property, options);
  return Math.round((1.0 - percentile) * 100);
});

/**
  Displays a float nicely

  @method float
  @for Ember.Handlebars
**/
Ember.Handlebars.registerHelper('float', function(property, options) {
  var x = Ember.Handlebars.get(this, property, options);
  if (!x) return "0";
  if (Math.round(x) === x) return x;
  return x.toFixed(3);
});

/**
  Display logic for numbers.

  @method number
  @for Handlebars
**/
Handlebars.registerHelper('number', function(property, options) {
  var n, orig, title, result;
  orig = parseInt(Ember.Handlebars.get(this, property, options), 10);
  if (isNaN(orig)) {
    orig = 0;
  }
  title = orig;
  if (options.hash.numberKey) {
    title = I18n.t(options.hash.numberKey, {
      number: orig
    });
  }
  // Round off the thousands to one decimal place
  n = orig;
  if (orig > 999 && !options.hash.noTitle) {
    n = (orig / 1000).toFixed(1) + "K";
  }

  result = "<span class='number'";

  if(n !== title) {
    result += " title='" + title + "'";
  }

  result += ">" + n + "</span>";
  return new Handlebars.SafeString(result);
});

/**
  Display logic for dates.

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

/**
  Produces a link to the FAQ

  @method faqLink
  @for Handlebars
**/
Handlebars.registerHelper('faqLink', function(property, options) {
  return new Handlebars.SafeString(
    "<a href='" +
    (Discourse.SiteSettings.faq_url.length > 0 ? Discourse.SiteSettings.faq_url : Discourse.getURL('/faq')) +
    "'>" + I18n.t('faq') + "</a>"
  );
});
