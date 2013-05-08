/**
  Breaks up a long string

  @method breakUp
  @for Handlebars
**/
Handlebars.registerHelper('breakUp', function(property, options) {
  var prop, result, tokens;
  prop = Ember.Handlebars.get(this, property, options);
  if (!prop) return "";

  tokens = prop.match(new RegExp(".{1,14}", 'g'));
  if (tokens.length === 1) return prop;

  result = "";
  tokens.each(function(token, index) {
    result += token;
    if (token.indexOf(' ') === -1 && (index < tokens.length - 1)) {
      result += "- ";
    }
  });
  return result;
});

/**
  Truncates long strings

  @method shorten
  @for Handlebars
**/
Handlebars.registerHelper('shorten', function(property, options) {
  return Ember.Handlebars.get(this, property, options).truncate(35);
});

/**
  Produces a link to a topic

  @method topicLink
  @for Handlebars
**/
Handlebars.registerHelper('topicLink', function(property, options) {
  var title, topic;
  topic = Ember.Handlebars.get(this, property, options);
  title = topic.get('fancy_title') || topic.get('title');
  return "<a href='" + (topic.get('lastReadUrl')) + "' class='title'>" + title + "</a>";
});

/**
  Produces a link to a category

  @method categoryLink
  @for Handlebars
**/
Handlebars.registerHelper('categoryLink', function(property, options) {
  var category = Ember.Handlebars.get(this, property, options);
  return new Handlebars.SafeString(Discourse.Utilities.categoryLink(category));
});

/**
  Inserts a Discourse.TextField to allow the user to enter information.

  @method textField
  @for Handlebars
**/
Ember.Handlebars.registerHelper('textField', function(options) {
  var hash = options.hash,
      types = options.hashTypes;

  for (var prop in hash) {
    if (types[prop] === 'ID') {
      hash[prop + 'Binding'] = hash[prop];
      delete hash[prop];
    }
  }

  return Ember.Handlebars.helpers.view.call(this, Discourse.TextField, options);
});

/**
  Produces a bound link to a category

  @method boundCategoryLink
  @for Handlebars
**/
Ember.Handlebars.registerBoundHelper('boundCategoryLink', function(category) {
  return new Handlebars.SafeString(Discourse.Utilities.categoryLink(category));
});

/**
  Produces a link to a route with support for i18n on the title

  @method titledLinkTo
  @for Handlebars
**/
Handlebars.registerHelper('titledLinkTo', function(name, object) {
  var options = [].slice.call(arguments, -1)[0];
  if (options.hash.titleKey) {
    options.hash.title = Em.String.i18n(options.hash.titleKey);
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
  return url.truncate(80);
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

  if( user ) {
    var username = Em.get(user, 'username');
    if (!username) username = Em.get(user, options.hash.usernamePath);

    var avatarTemplate = Ember.get(user, 'avatar_template');
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
      username: username,
      title: title || username,
      avatarTemplate: avatarTemplate
    }));
  } else {
    return '';
  }
});

/**
  Nicely format a date without a binding since the date doesn't need to change.

  @method unboundDate
  @for Handlebars
**/
Handlebars.registerHelper('unboundDate', function(property, options) {
  var dt;
  dt = new Date(Ember.Handlebars.get(this, property, options));
  return dt.format("long");
});

/**
  Display a date related to an edit of a post

  @method editDate
  @for Handlebars
**/
Handlebars.registerHelper('editDate', function(property, options) {
  var dt, yesterday;
  dt = Date.create(Ember.Handlebars.get(this, property, options));
  yesterday = new Date() - (60 * 60 * 24 * 1000);
  if (yesterday > dt.getTime()) {
    return dt.format("long");
  } else {
    return dt.relative();
  }
});

/**
  Displays a percentile based on a `percent_rank` field

  @method percentile
  @for Ember.Handlebars
**/
Ember.Handlebars.registerHelper('percentile', function(property, options) {
  var percentile = Ember.Handlebars.get(this, property, options);
  return Math.round((1.0 - percentile) * 100)
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
  return x.toFixed(3)
});

/**
  Display logic for numbers.

  @method number
  @for Handlebars
**/
Handlebars.registerHelper('number', function(property, options) {
  var n, orig, title;
  orig = parseInt(Ember.Handlebars.get(this, property, options), 10);
  if (isNaN(orig)) {
    orig = 0;
  }
  title = orig;
  if (options.hash.numberKey) {
    title = Em.String.i18n(options.hash.numberKey, {
      number: orig
    });
  }
  // Round off the thousands to one decimal place
  n = orig;
  if (orig > 999) {
    n = (orig / 1000).toFixed(1) + "K";
  }
  return new Handlebars.SafeString("<span class='number' title='" + title + "'>" + n + "</span>");
});

/**
  Display logic for dates.

  @method date
  @for Handlebars
**/
Handlebars.registerHelper('date', function(property, options) {
  var displayDate, dt, fiveDaysAgo, oneMinuteAgo, fullReadable, humanized, leaveAgo, val;
  if (property.hash) {
    if (property.hash.leaveAgo) {
      leaveAgo = property.hash.leaveAgo === "true";
    }
    if (property.hash.path) {
      property = property.hash.path;
    }
  }
  val = Ember.Handlebars.get(this, property, options);
  if (!val) {
    return new Handlebars.SafeString("&mdash;");
  }
  dt = new Date(val);
  fullReadable = dt.format("long");
  displayDate = "";
  fiveDaysAgo = (new Date()) - 432000000;
  oneMinuteAgo = (new Date()) - 60000;
  if (oneMinuteAgo <= dt.getTime() && dt.getTime() <= (new Date())) {
    displayDate = Em.String.i18n("now");
  } else if (fiveDaysAgo > (dt.getTime())) {
    if ((new Date()).getFullYear() !== dt.getFullYear()) {
      displayDate = dt.format("short");
    } else {
      displayDate = dt.format("short_no_year");
    }
  } else {
    humanized = dt.relative();
    if (!humanized) {
      return "";
    }
    displayDate = humanized;
    if (!leaveAgo) {
        displayDate = (dt.millisecondsAgo()).duration();
    }
  }
  return new Handlebars.SafeString("<span class='date' title='" + fullReadable + "'>" + displayDate + "</span>");
});

/**
  A personalized name for display

  @method personalizedName
  @for Handlebars
**/
Handlebars.registerHelper('personalizedName', function(property, options) {
  var name, username;
  name = Ember.Handlebars.get(this, property, options);
  if (options.hash.usernamePath) {
    username = Ember.Handlebars.get(this, options.hash.usernamePath, options);
  }
  if (username !== Discourse.get('currentUser.username')) {
    return name;
  }
  return Em.String.i18n('you');
});
