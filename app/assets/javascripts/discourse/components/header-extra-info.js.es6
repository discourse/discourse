import DiscourseURL from 'discourse/lib/url';

const TopicCategoryComponent = Ember.Component.extend({
  needsSecondRow: Ember.computed.gt('secondRowItems.length', 0),
  secondRowItems: function() { return []; }.property(),

  pmPath: function() {
    var currentUser = this.get('currentUser');
    return currentUser && currentUser.pmPath(this.get('topic'));
  }.property('topic'),

  showPrivateMessageGlyph: function() {
    return !this.get('topic.is_warning') && this.get('topic.isPrivateMessage');
  }.property('topic.is_warning', 'topic.isPrivateMessage'),

  actions: {
    jumpToTopPost() {
      const topic = this.get('topic');
      if (topic) {
        DiscourseURL.routeTo(topic.get('firstPostUrl'));
      }
    }
  }

});

let id = 0;

// Allow us (and plugins) to register themselves as needing a second
// row in the header. If there is at least one thing in the second row
// the style changes to accomodate it.
function needsSecondRowIf(prop, cb) {
  const rowId = "_second_row_" + (id++),
        methodHash = {};

  methodHash[id] = function() {
    const secondRowItems = this.get('secondRowItems'),
          propVal = this.get(prop);
    if (cb.call(this, propVal)) {
      secondRowItems.addObject(rowId);
    } else {
      secondRowItems.removeObject(rowId);
    }
  }.observes(prop).on('init');

  TopicCategoryComponent.reopen(methodHash);
}

needsSecondRowIf('topic.category', function(cat) {
  return cat && (!cat.get('isUncategorizedCategory') || !this.siteSettings.suppress_uncategorized_badge);
});

export default TopicCategoryComponent;
export { needsSecondRowIf };
