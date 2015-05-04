import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'li',
  classNameBindings: ['active', 'noGlyph'],

  rerenderTriggers: ['content.count', 'count'],
  noGlyph: Em.computed.empty('icon'),

  isIndexStream: function() {
    return !this.get('content');
  }.property('content.count'),

  active: function() {
    if (this.get('isIndexStream')) {
      return !this.get('userActionType');
    }
    const content = this.get('content');
    if (content) {
      return parseInt(this.get('userActionType'), 10) === parseInt(Em.get(content, 'action_type'), 10);
    }
  }.property('userActionType', 'isIndexStream'),

  activityCount: function() {
    return this.get('content.count') || this.get('count') || 0;
  }.property('content.count', 'count'),

  typeKey: function() {
    const actionType = this.get('content.action_type');
    if (actionType === Discourse.UserAction.TYPES.messages_received) { return ""; }

    const result = Discourse.UserAction.TYPES_INVERTED[actionType];
    if (!result) { return ""; }

    // We like our URLS to have hyphens, not underscores
    return "/" + result.replace("_", "-");
  }.property('content.action_type'),

  url: function() {
    return "/users/" + this.get('user.username_lower') + "/activity" + this.get('typeKey');
  }.property('typeKey', 'user.username_lower'),

  description: function() {
    return this.get('content.description') || I18n.t("user.filters.all");
  }.property('content.description'),

  renderString(buffer) {
    buffer.push("<a href='" + this.get('url') + "'>");
    const icon = this.get('icon');
    if (icon) {
      buffer.push("<i class='glyph fa fa-" + icon + "'></i> ");
    }
    buffer.push(this.get('description') + " <span class='count'>(" + this.get('activityCount') + ")</span></a>");
  },

  icon: function() {
    switch(parseInt(this.get('content.action_type'), 10)) {
      case Discourse.UserAction.TYPES.likes_received: return "heart";
      case Discourse.UserAction.TYPES.bookmarks: return "bookmark";
      case Discourse.UserAction.TYPES.edits: return "pencil";
      case Discourse.UserAction.TYPES.replies: return "reply";
      case Discourse.UserAction.TYPES.mentions: return "at";
    }
  }.property("content.action_type")
});
