import RestModel from 'discourse/models/rest';
import Singleton from 'discourse/mixins/singleton';

// A data model representing current session data. You can put transient
// data here you might want later. It is not stored or serialized anywhere.
const Session = RestModel.extend({
  init: function() {
    this.set('highestSeenByTopic', {});
  }
});

Session.reopenClass(Singleton);
export default Session;
