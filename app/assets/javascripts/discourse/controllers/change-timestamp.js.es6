import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import DiscourseURL from 'discourse/lib/url';

// Modal related to changing the timestamp of posts
export default Ember.Controller.extend(ModalFunctionality, {
  needs: ['topic'],

  topicController: Em.computed.alias('controllers.topic'),
  saving: false,
  date: '',
  time: '',

  @computed('saving')
  buttonTitle(saving) {
    return saving ? I18n.t('saving') : I18n.t('topic.change_timestamp.action');
  },

  @computed('date', 'time')
  createdAt(date, time) {
    return moment(date + ' ' + time, 'YYYY-MM-DD HH:mm:ss');
  },

  @computed('createdAt')
  validTimestamp(createdAt) {
    return moment().diff(createdAt, 'minutes') < 0;
  },

  @computed('saving', 'date', 'validTimestamp')
  buttonDisabled() {
    if (this.get('saving') || this.get('validTimestamp')) return true;
    return Ember.isEmpty(this.get('date'));
  },

  onShow: function() {
    this.setProperties({
      date: moment().format('YYYY-MM-DD')
    });
  },

  actions: {
    changeTimestamp: function() {
      this.set('saving', true);
      const self = this,
            topic = this.get('topicController.model');

      Discourse.Topic.changeTimestamp(
        topic.get('id'),
        this.get('createdAt').unix()
      ).then(function() {
        self.send('closeModal');
        self.setProperties({ date: '', time: '', saving: false });
        Em.run.next(() => { DiscourseURL.routeTo(topic.get('url')); });
      }).catch(function() {
        self.flash(I18n.t('topic.change_timestamp.error'), 'alert-error');
        self.set('saving', false);
      });
      return false;
    }
  }
});
