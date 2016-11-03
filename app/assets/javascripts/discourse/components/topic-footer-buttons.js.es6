import computed from 'ember-addons/ember-computed-decorators';
import DelegatedActions from 'discourse/mixins/delegated-actions';

export default Ember.Component.extend(DelegatedActions, {
  elementId: 'topic-footer-buttons',

  // Allow us to extend it
  layoutName: 'components/topic-footer-buttons',

  init() {
    this._super();
    this.delegateAll(this.get('topicDelegated'));
  },

  @computed('topic.details.can_invite_to')
  canInviteTo(result) {
    return !this.site.mobileView && result;
  },

  inviteDisabled: Ember.computed.or('topic.archived', 'topic.closed', 'topic.deleted'),

  @computed
  showAdminButton() {
    return !this.site.mobileView && this.currentUser.get('canManageTopic');
  },

  @computed('topic.message_archived')
  archiveIcon: archived => archived ? '' : 'folder',

  @computed('topic.message_archived')
  archiveTitle: archived => archived ? 'topic.move_to_inbox.help' : 'topic.archive_message.help',

  @computed('topic.message_archived')
  archiveLabel: archived => archived ? "topic.move_to_inbox.title" : "topic.archive_message.title",

  @computed('topic.bookmarked')
  bookmarkClass: bookmarked => bookmarked ? 'bookmark bookmarked' : 'bookmark',

  @computed('topic.bookmarked')
  bookmarkLabel: bookmarked => bookmarked ? 'bookmarked.clear_bookmarks' : 'bookmarked.title',

  @computed('topic.bookmarked')
  bookmarkTitle: bookmarked => bookmarked ? "bookmarked.help.unbookmark" : "bookmarked.help.bookmark",

});
