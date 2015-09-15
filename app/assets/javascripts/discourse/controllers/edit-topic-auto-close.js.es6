import { observes } from "ember-addons/ember-computed-decorators";
import ModalFunctionality from 'discourse/mixins/modal-functionality';

// Modal related to auto closing of topics
export default Ember.Controller.extend(ModalFunctionality, {
  auto_close_valid: true,
  auto_close_invalid: Em.computed.not('auto_close_valid'),

  @observes("model.details.auto_close_at", "model.details.auto_close_hours")
  setAutoCloseTime() {
    let autoCloseTime = null;

    if (this.get("model.details.auto_close_based_on_last_post")) {
      autoCloseTime = this.get("model.details.auto_close_hours");
    } else if (this.get("model.details.auto_close_at")) {
      const closeTime = new Date(this.get("model.details.auto_close_at"));
      if (closeTime > new Date()) {
        autoCloseTime = moment(closeTime).format("YYYY-MM-DD HH:mm");
      }
    }

    this.set("model.auto_close_time", autoCloseTime);
  },

  actions: {
    saveAutoClose() { this.setAutoClose(this.get("model.auto_close_time")); },
    removeAutoClose() { this.setAutoClose(null); }
  },

  setAutoClose(time) {
    const self = this;
    this.send('hideModal');
    Discourse.ajax({
      url: `/t/${this.get('model.id')}/autoclose`,
      type: 'PUT',
      dataType: 'json',
      data: {
        auto_close_time: time,
        auto_close_based_on_last_post: this.get("model.details.auto_close_based_on_last_post"),
        timezone_offset: (new Date().getTimezoneOffset())
      }
    }).then(result => {
      if (result.success) {
        this.send('closeModal');
        this.set('model.details.auto_close_at', result.auto_close_at);
        this.set('model.details.auto_close_hours', result.auto_close_hours);
      } else {
        bootbox.alert(I18n.t('composer.auto_close.error'), function() { self.send('reopenModal'); } );
      }
    }).catch(() => {
      bootbox.alert(I18n.t('composer.auto_close.error'), function() { self.send('reopenModal'); } );
    });
  }

});
