import { on }  from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
import { keepAliveDuration } from 'discourse/plugins/discourse-presence/discourse/components/composer-presence-display';

const bufferTime = 3000;

export default Ember.Component.extend({
  topicId: null,

  messageBusChannel: null,
  presenceUsers: null,

  @on('didInsertElement')
  _inserted() {
    this.set("presenceUsers", []);
    const messageBusChannel = `/presence/topic/${this.get('topicId')}`;
    this.set('messageBusChannel', messageBusChannel);

    var firstMessage = true;

    this.messageBus.subscribe(messageBusChannel, message => {

      let users = message.users;

      // account for old messages,
      // we only do this once to allow for some bad clocks
      if (firstMessage) {
        const old = ((new Date()) / 1000) - ((keepAliveDuration / 1000) * 2);
        if (message.time && (message.time < old)) {
          users = [];
        }
        firstMessage = false;
      }

      Em.run.cancel(this._expireTimer);

      this.set("presenceUsers", users);

      this._expireTimer = Em.run.later(
        this,
        () => {
          this.set("presenceUsers", []);
        },
        keepAliveDuration + bufferTime
      );
    }, -2); /* subscribe at position -2 so we get last message */
  },

  @on('willDestroyElement')
  _destroyed() {
    const channel = this.get("messageBusChannel");
    if (channel) {
      Em.run.cancel(this._expireTimer);
      this.messageBus.unsubscribe(channel);
      this.set("messageBusChannel", null);
    }
  },

  @computed('presenceUsers', 'currentUser.id')
  users(presenceUsers, currentUser_id){
    return (presenceUsers || []).filter(user => user.id !== currentUser_id);
  },

  @computed('users.length')
  shouldDisplay(length){
    return length > 0;
  }
});
