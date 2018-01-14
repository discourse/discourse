import computed from "ember-addons/ember-computed-decorators";
import { extractError } from 'discourse/lib/ajax-error';
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Badge from 'discourse/models/badge';
import UserBadge from 'discourse/models/user-badge';

export default Ember.Controller.extend(ModalFunctionality, {
  topicController: Ember.inject.controller("topic"),
  loading: true,
  saving: false,
  selectedBadgeId: null,
  allBadges: [],
  userBadges: [],

  @computed('topicController.selectedPosts')
  post() {
    return this.get('topicController.selectedPosts')[0];
  },

  @computed('post')
  badgeReason(post) {
    const url = post.get('url');
    const protocolAndHost = window.location.protocol + '//' + window.location.host;

    return url.indexOf('/') === 0 ? protocolAndHost + url : url;
  },

  @computed('allBadges.[]', 'userBadges.[]')
  grantableBadges(allBadges, userBadges) {
    const granted = userBadges.reduce((map, badge) => {
      map[badge.get('badge_id')] = true;
      return map;
    }, {});

    return allBadges.filter(badge => {
      return badge.get('enabled')
        && badge.get('manually_grantable')
        && (!granted[badge.get('id')] || badge.get('multiple_grant'));
    });
  },

  noGrantableBadges: Ember.computed.empty('grantableBadges'),

  @computed('selectedBadgeId', 'grantableBadges')
  selectedBadgeGrantable(selectedBadgeId, grantableBadges) {
    return grantableBadges && grantableBadges.find(badge => badge.get('id') === selectedBadgeId);
  },

  @computed("saving", "selectedBadgeGrantable")
  buttonDisabled(saving, selectedBadgeGrantable) {
    return saving || !selectedBadgeGrantable;
  },

  onShow() {
    this.set('loading', true);

    Ember.RSVP.all([Badge.findAll(), UserBadge.findByUsername(this.get('post.username'))])
      .then(([allBadges, userBadges]) => {
        this.setProperties({
          'allBadges': allBadges,
          'userBadges': userBadges,
          'loading': false,
        });
      });
  },

  actions: {
    grantBadge() {
      const username = this.get('post.username');

      this.set('saving', true);

      UserBadge.grant(this.get('selectedBadgeId'), username, this.get('badgeReason'))
        .then(newBadge => {
          this.get('userBadges').pushObject(newBadge);
          this.set('selectedBadgeId', null);
          this.flash(I18n.t(
            'badges.successfully_granted',
            { username: username, badge: newBadge.get('badge.name') }
          ), 'success');
        }, error => {
          this.flash(extractError(error), 'error');
        })
        .finally(() => this.set('saving', false));
    }
  }
});
