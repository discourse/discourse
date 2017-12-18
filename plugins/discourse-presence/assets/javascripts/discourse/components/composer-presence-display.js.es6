import { ajax } from 'discourse/lib/ajax';
import { observes, on }  from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
import pageVisible from 'discourse/lib/page-visible';

export const keepAliveDuration = 10000;
const bufferTime = 3000;

export default Ember.Component.extend({
  composer: Ember.inject.controller(),

  // Passed in variables
  action: null,
  post: null,
  topic: null,
  reply: null,

  // Internal variables
  oldPresenceState: null,
  presenceState: null,
  keepAliveTimer: null,
  messageBusChannel: null,
  presenceUsers: null,

  @on('didInsertElement')
  composerOpened(){
    this.updateStateObject();
  },

  @on('willDestroyElement')
  composerClosing(){
    this.updateStateObject({closing: true});
  },

  @observes('reply', 'title')
  dataChanged() {
    if (!this._dataChanged && (new Date() - this._lastPublish) > keepAliveDuration) {
      this._dataChanged = true;
      this.keepPresenceAlive();
    } else {
      this._dataChanged = true;
    }
  },

  @observes('action', 'post', 'topic')
  composerStateChanged(){
    Ember.run.once(this, 'updateStateObject');
  },

  updateStateObject(opts){
    const isClosing = opts && opts.closing;

    var stateObject = null;

    if(!isClosing && this.shouldSharePresence(this.get('action'))){
      stateObject = {};

      stateObject.action = this.get('action');

      // Add some context if we're editing or replying
      switch(stateObject.action){
        case 'edit':
          stateObject.post_id = this.get('post.id');
          break;
        case 'reply':
          stateObject.topic_id = this.get('topic.id');
          break;
        default:
          break; // createTopic or privateMessage
      }
    }

    this.set('oldPresenceState', this.get('presenceState'));
    this.set('presenceState', stateObject);
  },

  _ACTIONS: ['edit', 'reply'],

  shouldSharePresence(action){
    return this._ACTIONS.includes(action);
  },

  @observes('presenceState')
  presenceStateChanged(){
    if(this.get('messageBusChannel')){
      this.messageBus.unsubscribe(this.get('messageBusChannel'));
      this.set('messageBusChannel', null);
    }

    this.set('presenceUsers', []);
    this.publish({
      response_needed: true,
      previous: this.get('oldPresenceState'),
      current: this.get('presenceState')
    }).then((data) => {
      const messageBusChannel = data['messagebus_channel'];
      if(messageBusChannel){
        const users = data['users'];
        const messageBusId = data['messagebus_id'];
        this.set('presenceUsers', users);
        this.set('messageBusChannel', messageBusChannel);
        this.messageBus.subscribe(messageBusChannel, message => {
          this.set('presenceUsers', message['users']);
          this.timeoutPresence();
        }, messageBusId);
      }
    }).catch((error) => {
      // This isn't a critical failure, so don't disturb the user
      if (window.console && console.error) {
        console.error("Error publishing composer status", error);
      }
    });

    Ember.run.cancel(this.get('keepAliveTimer'));
    if(this.shouldSharePresence(this.get('presenceState.action'))){
      // Send presence data every 10 seconds
      this.set('keepAliveTimer', Ember.run.later(this, 'keepPresenceAlive', keepAliveDuration));
    }
  },

  timeoutPresence() {
    Ember.run.cancel(this._timeoutTimer);
    this._timeoutTimer = Ember.run.later(
      this,
      () => { this.set("presenceUsers", []); },
      keepAliveDuration + bufferTime
    );
  },

  publish(data) {
    this._lastPublish = new Date();
    this._dataChanged = false;

    return ajax('/presence/publish', {
      type: 'POST',
      data: data
    });
  },

  keepPresenceAlive(){
    // If we're not replying or editing,
    // don't update anything, and don't schedule this task again
    if(!this.shouldSharePresence(this.get('presenceState.action'))){
      return;
    }

    if (this._dataChanged) {
      this._dataChanged = false;
      const browserInFocus = pageVisible();

      // Only send the keepalive message if the browser has focus
      if(browserInFocus){
        this.publish({
          current: this.get('presenceState')
        }).catch((error) => {
          // This isn't a critical failure, so don't disturb the user
          if (window.console && console.error) {
            console.error("Error publishing composer status", error);
          }
        });
      }
    }

    // Schedule again in another 10 seconds
    Ember.run.cancel(this.get('keepAliveTimer'));
    this.set('keepAliveTimer', Ember.run.later(this, 'keepPresenceAlive', keepAliveDuration));
  },

  @computed('presenceUsers', 'currentUser.id')
  users(presenceUsers, currentUser_id){
    return (presenceUsers || []).filter(user => user.id !== currentUser_id);
  },

  @computed('presenceState.action')
  isReply(action){
    return action === 'reply';
  },

  @computed('users.length')
  shouldDisplay(length){
    return length > 0;
  }
});
