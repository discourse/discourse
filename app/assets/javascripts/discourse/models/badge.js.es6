import BadgeGrouping from 'discourse/models/badge-grouping';
import RestModel from 'discourse/models/rest';

const Badge = RestModel.extend({

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
    const i18nKey = "badges.badge." + this.get('i18nNameKey') + ".name";
    return I18n.t(i18nKey, {defaultValue: this.get('name')});
  }.property('name', 'i18nNameKey'),

  /**
    The i18n translated description for this badge. Returns the null if no
    translation exists.

    @property translatedDescription
    @type {String}
  **/
  translatedDescription: function() {
    const i18nKey = "badges.badge." + this.get('i18nNameKey') + ".description";
    let translation = I18n.t(i18nKey);
    if (translation.indexOf(i18nKey) !== -1) {
      translation = null;
    }
    return translation;
  }.property('i18nNameKey'),

  displayDescription: function(){
    // we support html in description but in most places do not need it
    return this.get('displayDescriptionHtml').replace(/<[^>]*>/g, "");
  }.property('displayDescriptionHtml'),

  /**
    Display-friendly description string. Returns either a translation or the
    original description string.

    @property displayDescription
    @type {String}
  **/
  displayDescriptionHtml: function() {
    const translated = this.get('translatedDescription');
    return (translated === null ? this.get('description') : translated) || "";
  }.property('description', 'translatedDescription'),

  /**
    Update this badge with the response returned by the server on save.

    @method updateFromJson
    @param {Object} json The JSON response returned by the server
  **/
  updateFromJson: function(json) {
    const self = this;
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

  badgeTypeClassName: function() {
    const type = this.get('badge_type.name') || "";
    return "badge-type-" + type.toLowerCase();
  }.property('badge_type.name'),

  /**
    Save and update the badge from the server's response.

    @method save
    @returns {Promise} A promise that resolves to the updated `Discourse.Badge`
  **/
  save: function(data) {
    let url = "/admin/badges",
        requestType = "POST";
    const self = this;

    if (this.get('id')) {
      // We are updating an existing badge.
      url += "/" + this.get('id');
      requestType = "PUT";
    }

    return Discourse.ajax(url, {
      type: requestType,
      data: data
    }).then(function(json) {
      self.updateFromJson(json);
      return self;
    }).catch(function(error) {
      throw error;
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

Badge.reopenClass({
  /**
    Create `Discourse.Badge` instances from the server JSON response.

    @method createFromJson
    @param {Object} json The JSON returned by the server
    @returns Array or instance of `Discourse.Badge` depending on the input JSON
  **/
  createFromJson: function(json) {
    // Create BadgeType objects.
    const badgeTypes = {};
    if ('badge_types' in json) {
      json.badge_types.forEach(function(badgeTypeJson) {
        badgeTypes[badgeTypeJson.id] = Ember.Object.create(badgeTypeJson);
      });
    }

    const badgeGroupings = {};
    if ('badge_groupings' in json) {
      json.badge_groupings.forEach(function(badgeGroupingJson) {
        badgeGroupings[badgeGroupingJson.id] = BadgeGrouping.create(badgeGroupingJson);
      });
    }

    // Create Badge objects.
    let badges = [];
    if ("badge" in json) {
      badges = [json.badge];
    } else {
      badges = json.badges;
    }
    badges = badges.map(function(badgeJson) {
      const badge = Discourse.Badge.create(badgeJson);
      badge.set('badge_type', badgeTypes[badge.get('badge_type_id')]);
      badge.set('badge_grouping', badgeGroupings[badge.get('badge_grouping_id')]);
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
    let listable = "";
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

export default Badge;

