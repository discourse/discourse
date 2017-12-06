import { ajax } from 'discourse/lib/ajax';
import { observes, on }  from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  topicId: null,

  messageBusChannel: null,
  presenceUsers: null,

  @on('didInsertElement')
  _inserted() {
    this.set("presenceUsers", []);

    ajax(`/presence/ping/${this.get("topicId")}`).then((data) => {
      this.setProperties({
        messageBusChannel: data.messagebus_channel,
        presenceUsers: data.users,
      });
      this.messageBus.subscribe(data.messagebus_channel, message => {
        console.log(message)
        this.set("presenceUsers", message.users);
      }, data.messagebus_id);
    });
  },

  @on('willDestroyElement')
  _destroyed() {
    if (this.get("messageBusChannel")) {
      this.messageBus.unsubscribe(this.get("messageBusChannel"));
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
