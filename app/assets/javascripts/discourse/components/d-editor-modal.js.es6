import { observes, on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':d-editor-modal', 'hidden'],

  @observes('hidden')
  _hiddenChanged() {
    if (!this.get('hidden')) {
      Ember.run.scheduleOnce('afterRender', () => {
        const $modal = this.$();
        const $parent = this.$().closest('.d-editor');
        const w = $parent.width();
        const h = $parent.height();
        const dir = $('html').css('direction') === 'rtl' ? 'right' : 'left';
        const offset = (w / 2) - ($modal.outerWidth() / 2);
        $modal.css(dir, offset + 'px');
        parent.$('.d-editor-overlay').removeClass('hidden').css({ width: w, height: h});
        this.$('input:eq(0)').focus();
      });
    } else {
      parent.$('.d-editor-overlay').addClass('hidden');
    }
  },

  @on('didInsertElement')
  _listenKeys() {
    this.$().on('keydown.d-modal', key => {
      if (this.get('hidden')) { return; }

      if (key.keyCode === 27) {
        this.send('cancel');
        return false;
      }
      if (key.keyCode === 13) {
        this.send('ok');
        return false;
      }
    });
  },

  @on('willDestroyElement')
  _stopListening() {
    this.$().off('keydown.d-modal');
  },

  actions: {
    ok() {
      this.set('hidden', true);
      this.sendAction('okAction');
    },

    cancel() {
      this.set('hidden', true);
    }
  }
});
