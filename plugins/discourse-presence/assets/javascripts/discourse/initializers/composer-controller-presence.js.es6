import { ajax } from 'discourse/lib/ajax';
import { observes}  from 'ember-addons/ember-computed-decorators';
import { withPluginApi } from 'discourse/lib/plugin-api';
import pageVisible from 'discourse/lib/page-visible';

function initialize(api) {
  api.modifyClass('controller:composer', {

    oldPresenceState: { compose_state: 'closed' },
    presenceState: { compose_state: 'closed' },
    keepAliveTimer: null,
    messageBusChannel: null,

    @observes('model.composeState', 'model.action', 'model.post', 'model.topic')
    openStatusChanged(){
      Ember.run.once(this, 'updateStateObject');
    },

    updateStateObject(){
      const composeState = this.get('model.composeState');

      const stateObject = {
        compose_state: composeState ? composeState : 'closed'
      };

      if(stateObject.compose_state === 'open'){
        stateObject.action = this.get('model.action');

        // Add some context if we're editing or replying
        switch(stateObject.action){
          case 'edit':
            stateObject.post_id = this.get('model.post.id');
            break;
          case 'reply':
            stateObject.topic_id = this.get('model.topic.id');
            break;
          default:
            break; // createTopic or privateMessage
        }
      }

      this.set('oldPresenceState', this.get('presenceState'));
      this.set('presenceState', stateObject);
    },

    shouldSharePresence(){
      const isOpen = this.get('presenceState.compose_state') !== 'open';
      const isEditing = ['edit','reply'].includes(this.get('presenceState.action'));
      return isOpen && isEditing;
    },

    @observes('presenceState')
    presenceStateChanged(){
      if(this.get('messageBusChannel')){
        this.messageBus.unsubscribe(this.get('messageBusChannel'));
        this.set('messageBusChannel', null);
      }

      this.set('presenceUsers', []);

      ajax('/presence/publish/', {
        type: 'POST',
        data: {
          response_needed: true,
          previous: this.get('oldPresenceState'),
          current: this.get('presenceState')
        }
      }).then((data) => {
        const messageBusChannel = data['messagebus_channel'];
        if(messageBusChannel){
          const users = data['users'];
          const messageBusId = data['messagebus_id'];
          this.set('presenceUsers', users);
          this.set('messageBusChannel', messageBusChannel);
          this.messageBus.subscribe(messageBusChannel, message => {
            this.set('presenceUsers', message['users']);
          }, messageBusId);
        }
      }).catch((error) => {
        // This isn't a critical failure, so don't disturb the user
        console.error("Error publishing composer status", error);
      });


      Ember.run.cancel(this.get('keepAliveTimer'));
      if(this.shouldSharePresence()){
        // Send presence data every 10 seconds
        this.set('keepAliveTimer', Ember.run.later(this, 'keepPresenceAlive', 10000));
      }
    },



    keepPresenceAlive(){
      // If the composer isn't open, or we're not editing,
      // don't update anything, and don't schedule this task again
      if(!this.shouldSharePresence()){
        return;
      }

      // Only send the keepalive message if the browser has focus
      if(pageVisible()){
        ajax('/presence/publish/', {
          type: 'POST',
          data: { current: this.get('presenceState') }
        }).catch((error) => {
          // This isn't a critical failure, so don't disturb the user
          console.error("Error publishing composer status", error);
        });
      }

      // Schedule again in another 30 seconds
      Ember.run.cancel(this.get('keepAliveTimer'));
      this.set('keepAliveTimer', Ember.run.later(this, 'keepPresenceAlive', 10000));
    }

  });
}

export default {
  name: "composer-controller-presence",
  after: "message-bus",

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.presence_enabled) withPluginApi('0.8.9', initialize);
  }
};
