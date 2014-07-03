/**
  A data model representing a badge on Discourse

  @class Badge
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Badge = Discourse.Model.extend({
  /**
    Is this a new badge?

    @property newBadge
    @type {String}
  **/
  newBadge: Em.computed.none('id'),

  /**
    @private

    The name key to use for fetching i18n translations.

    @property i18nNameKey
    @type {String}
  **/
  i18nNameKey: function() {
    return this.get('name').toLowerCase().replace(/\s/g, '_');
  }.property('name'),

  /**
    The display name of this badge. Attempts to use a translation and falls back to
    the actual name.

    @property displayName
    @type {String}
  **/
  displayName: function() {
    var i18nKey = "badges.badge." + this.get('i18nNameKey') + ".name";
    return I18n.t(i18nKey, {defaultValue: this.get('name')});
  }.property('name', 'i18nNameKey'),

  /**
    The i18n translated description for this badge. Returns the null if no
    translation exists.

    @property translatedDescription
    @type {String}
  **/
  translatedDescription: function() {
    var i18nKey = "badges.badge." + this.get('i18nNameKey') + ".description",
        translation = I18n.t(i18nKey);
    if (translation.indexOf(i18nKey) !== -1) {
      translation = null;
    }
    return translation;
  }.property('i18nNameKey'),

  /**
    Display-friendly description string. Returns either a translation or the
    original description string.

    @property displayDescription
    @type {String}
  **/
  displayDescription: function() {
    var translated = this.get('translatedDescription');
    return translated === null ? this.get('description') : translated;
  }.property('description', 'translatedDescription'),

  /**
    Update this badge with the response returned by the server on save.

    @method updateFromJson
    @param {Object} json The JSON response returned by the server
  **/
  updateFromJson: function(json) {
    var self = this;
    if (json.badge) {
      Object.keys(json.badge).forEach(function(key) {
        self.set(key, json.badge[key]);
      });
    }
    if (json.badge_types) {
      json.badge_types.forEach(function(badgeType) {
        if (badgeType.id === self.get('badge_type_id')) {
          self.set('badge_type', Object.create(badgeType));
        }
      });
    }
  },

  /**
    Save and update the badge from the server's response.

    @method save
    @returns {Promise} A promise that resolves to the updated `Discourse.Badge`
  **/
  save: function() {
    this.set('savingStatus', I18n.t('saving'));
    this.set('saving', true);

    var url = "/admin/badges",
        requestType = "POST",
        self = this;

    if (!this.get('newBadge')) {
      // We are updating an existing badge.
      url += "/" + this.get('id');
      requestType = "PUT";
    }

    return Discourse.ajax(url, {
      type: requestType,
      data: {
        name: this.get('name'),
        description: this.get('description'),
        badge_type_id: this.get('badge_type_id'),
        allow_title: !!this.get('allow_title'),
        multiple_grant: !!this.get('multiple_grant'),
        listable: !!this.get('listable'),
        icon: this.get('icon')
      }
    }).then(function(json) {
      self.updateFromJson(json);
      self.set('savingStatus', I18n.t('saved'));
      self.set('saving', false);
      return self;
    });
  },

  /**
    Destroy the badge.

    @method destroy
    @returns {Promise} A promise that resolves to the server response
  **/
  destroy: function() {
    if (this.get('newBadge')) return Ember.RSVP.resolve();
    return Discourse.ajax("/admin/badges/" + this.get('id'), {
      type: "DELETE"
    });
  }
});

Discourse.Badge.reopenClass({
  /**
    Create `Discourse.Badge` instances from the server JSON response.

    @method createFromJson
    @param {Object} json The JSON returned by the server
    @returns Array or instance of `Discourse.Badge` depending on the input JSON
  **/
  createFromJson: function(json) {
    // Create BadgeType objects.
    var badgeTypes = {};
    if ('badge_types' in json) {
      json.badge_types.forEach(function(badgeTypeJson) {
        badgeTypes[badgeTypeJson.id] = Ember.Object.create(badgeTypeJson);
      });
    }

    // Create Badge objects.
    var badges = [];
    if ("badge" in json) {
      badges = [json.badge];
    } else {
      badges = json.badges;
    }
    badges = badges.map(function(badgeJson) {
      var badge = Discourse.Badge.create(badgeJson);
      badge.set('badge_type', badgeTypes[badge.get('badge_type_id')]);
      return badge;
    });
    if ("badge" in json) {
      return badges[0];
    } else {
      return badges;
    }
  },

  /**
    Find all `Discourse.Badge` instances that have been defined.

    @method findAll
    @returns {Promise} a promise that resolves to an array of `Discourse.Badge`
  **/
  findAll: function(opts) {
    var listable = "";
    if(opts && opts.onlyListable){
      listable = "?only_listable=true";
    }
    return Discourse.ajax('/badges.json' + listable).then(function(badgesJson) {
      return Discourse.Badge.createFromJson(badgesJson);
    });
  },

  /**
    Returns a `Discourse.Badge` that has the given ID.

    @method findById
    @param {Number} id ID of the badge
    @returns {Promise} a promise that resolves to a `Discourse.Badge`
  **/
  findById: function(id) {
    return Discourse.ajax("/badges/" + id).then(function(badgeJson) {
      return Discourse.Badge.createFromJson(badgeJson);
    });
  }
});
