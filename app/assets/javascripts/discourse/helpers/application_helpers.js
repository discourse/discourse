/*global humaneDate:true */

(function() {

  Handlebars.registerHelper('breakUp', function(property, options) {
    var prop, result, tokens;
    prop = Ember.Handlebars.get(this, property, options);
    if (!prop) {
      return "";
    }
    tokens = prop.match(new RegExp(".{1,14}", 'g'));
    if (tokens.length === 1) {
      return prop;
    }
    result = "";
    tokens.each(function(token, index) {
      result += token;
      if (token.indexOf(' ') === -1 && (index < tokens.length - 1)) {
        result += "- ";
      }
    });
    return result;
  });

  Handlebars.registerHelper('shorten', function(property, options) {
    var str;
    str = Ember.Handlebars.get(this, property, options);
    return str.truncate(35);
  });

  Handlebars.registerHelper('topicLink', function(property, options) {
    var title, topic;
    topic = Ember.Handlebars.get(this, property, options);
    title = topic.get('fancy_title') || topic.get('title');
    return "<a href='" + (topic.get('lastReadUrl')) + "' class='title excerptable'>" + title + "</a>";
  });

  Handlebars.registerHelper('categoryLink', function(property, options) {
    var category;
    category = Ember.Handlebars.get(this, property, options);
    return new Handlebars.SafeString(Discourse.Utilities.categoryLink(category));
  });

  Handlebars.registerHelper('titledLinkTo', function(name, object) {
    var options;
    options = [].slice.call(arguments, -1)[0];
    if (options.hash.titleKey) {
      options.hash.title = Em.String.i18n(options.hash.titleKey);
    }
    if (arguments.length === 3) {
      return Ember.Handlebars.helpers.linkTo.call(this, name, object, options);
    } else {
      return Ember.Handlebars.helpers.linkTo.call(this, name, options);
    }
  });

  Handlebars.registerHelper('shortenUrl', function(property, options) {
    var url;
    url = Ember.Handlebars.get(this, property, options);
    /* Remove trailing slash if it's a top level URL
    */

    if (url.match(/\//g).length === 3) {
      url = url.replace(/\/$/, '');
    }
    url = url.replace(/^https?:\/\//, '');
    url = url.replace(/^www\./, '');
    return url.truncate(80);
  });

  Handlebars.registerHelper('lower', function(property, options) {
    var o;
    o = Ember.Handlebars.get(this, property, options);
    if (o && typeof o === 'string') {
      return o.toLowerCase();
    } else {
      return "";
    }
  });

  Handlebars.registerHelper('avatar', function(user, options) {
    var title, username;
    if (typeof user === 'string') {
      user = Ember.Handlebars.get(this, user, options);
    }
    username = Em.get(user, 'username');
    if (!username) {
      username = Em.get(user, options.hash.usernamePath);
    }
    if (!options.hash.ignoreTitle) {
      title = Em.get(user, 'title') || Em.get(user, 'description');
    }
    return new Handlebars.SafeString(Discourse.Utilities.avatarImg({
      size: options.hash.imageSize,
      extraClasses: Em.get(user, 'extras') || options.hash.extraClasses,
      username: username,
      title: title || username,
      avatarTemplate: Ember.get(user, 'avatar_template') || options.hash.avatarTemplate
    }));
  });

  Handlebars.registerHelper('unboundDate', function(property, options) {
    var dt;
    dt = new Date(Ember.Handlebars.get(this, property, options));
    return dt.format("{d} {Mon}, {yyyy} {hh}:{mm}");
  });

  Handlebars.registerHelper('editDate', function(property, options) {
    var dt, yesterday;
    dt = Date.create(Ember.Handlebars.get(this, property, options));
    yesterday = new Date() - (60 * 60 * 24 * 1000);
    if (yesterday > dt.getTime()) {
      return dt.format("{d} {Mon}, {yyyy} {hh}:{mm}");
    } else {
      return humaneDate(dt);
    }
  });

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
    /* Round off the thousands to one decimal place
    */

    n = orig;
    if (orig > 999) {
      n = (orig / 1000).toFixed(1) + "K";
    }
    return new Handlebars.SafeString("<span class='number' title='" + title + "'>" + n + "</span>");
  });

  Handlebars.registerHelper('date', function(property, options) {
    var displayDate, dt, fiveDaysAgo, fullReadable, humanized, leaveAgo, val;
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
    fullReadable = dt.format("{d} {Mon}, {yyyy} {hh}:{mm}");
    displayDate = "";
    fiveDaysAgo = (new Date()) - 432000000;
    if (fiveDaysAgo > (dt.getTime())) {
      if ((new Date()).getFullYear() !== dt.getFullYear()) {
        displayDate = dt.format("{d} {Mon} '{yy}");
      } else {
        displayDate = dt.format("{d} {Mon}");
      }
    } else {
      humanized = humaneDate(dt);
      if (!humanized) {
        return "";
      }
      displayDate = humanized;
      if (!leaveAgo) {
        displayDate = displayDate.replace(' ago', '');
      }
    }
    return new Handlebars.SafeString("<span class='date' title='" + fullReadable + "'>" + displayDate + "</span>");
  });

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

}).call(this);
