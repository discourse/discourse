import ModalFunctionality from 'discourse/mixins/modal-functionality';

// Modal related to auto closing of topics
export default Ember.Controller.extend(ModalFunctionality, {
  auto_close_valid: true,
  auto_close_invalid: Em.computed.not('auto_close_valid'),
  disable_submit: Em.computed.or('auto_close_invalid', 'loading'),
  loading: false,

  setAutoCloseTime: function() {
    var autoCloseTime = null;

    if (this.get("model.details.auto_close_based_on_last_post")) {
      autoCloseTime = this.get("model.details.auto_close_hours");
    } else if (this.get("model.details.auto_close_at")) {
      var closeTime = new Date(this.get("model.details.auto_close_at"));
      if (closeTime > new Date()) {
        autoCloseTime = moment(closeTime).format("YYYY-MM-DD HH:mm");
      }
    }

    this.set("model.auto_close_time", autoCloseTime);
  }.observes("model.details.{auto_close_at,auto_close_hours}"),

  actions: {
    saveAutoClose: function() { this.setAutoClose(this.get("model.auto_close_time")); },
    removeAutoClose: function() { this.setAutoClose(null); }
  },

  setAutoClose: function(time) {
    var self = this;
    this.set('loading', true);
    Discourse.ajax({
      url: '/t/' + this.get('model.id') + '/autoclose',
      type: 'PUT',
      dataType: 'json',
      data: {
        auto_close_time: time,
        auto_close_based_on_last_post: this.get("model.details.auto_close_based_on_last_post"),
        timezone_offset: (new Date().getTimezoneOffset())
      }
    }).then(function(result) {
      self.set('loading', false);
      if (result.success) {
        self.send('closeModal');
        self.set('model.details.auto_close_at', result.auto_close_at);
        self.set('model.details.auto_close_hours', result.auto_close_hours);
      } else {
        bootbox.alert(I18n.t('composer.auto_close.error'));
      }
    }, function () {
      // TODO - incorrectly responds to network errors as bad input
      bootbox.alert(I18n.t('composer.auto_close.error'));
      self.set('loading', false);
    });
  },

  willCloseImmediately: function() {
    if (!this.get('model.details.auto_close_based_on_last_post')) {
      return false;
    }
    let closeDate = new Date(this.get('model.last_posted_at'));
    closeDate.setHours(closeDate.getHours() + this.get('model.auto_close_time'));
    return closeDate < new Date();
  }.property('model.details.auto_close_based_on_last_post', 'model.auto_close_time', 'model.last_posted_at'),

  willCloseI18n: function() {
    if (this.get('model.details.auto_close_based_on_last_post')) {
      return I18n.t('topic.auto_close_immediate', {hours: this.get('model.auto_close_time')});
    }
  }.property('model.details.auto_close_based_on_last_post', 'model.auto_close_time')

});
