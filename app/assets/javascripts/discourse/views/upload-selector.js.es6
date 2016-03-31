import ModalBodyView from "discourse/views/modal-body";
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import { uploadTranslate } from 'discourse/controllers/upload-selector';


export default ModalBodyView.extend({
  templateName: 'modal/upload-selector',
  classNames: ['upload-selector'],

  @computed()
  title() {
    return uploadTranslate("title");
  },

  touchStart(evt) {
    // HACK: workaround Safari iOS being really weird and not shipping click events
    if (this.capabilities.isSafari && evt.target.id === "filename-input") {
      this.$('#filename-input').click();
    }
  },

  @on('didInsertElement')
  @observes('controller.local')
  selectedChanged() {
    Ember.run.next(() => {
      // *HACK* to select the proper radio button
      const value = this.get('controller.local') ? 'local' : 'remote';
      $('input:radio[name="upload"]').val([value]);
      $('.inputs input:first').focus();
    });
  }

});
