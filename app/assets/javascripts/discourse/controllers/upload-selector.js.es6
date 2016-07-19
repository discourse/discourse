import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { default as computed } from 'ember-addons/ember-computed-decorators';
import { allowsAttachments, authorizesAllExtensions, authorizedExtensions } from 'discourse/lib/utilities';

export function uploadTranslate(key, options) {
  options = options || {};
  if (allowsAttachments()) { key += "_with_attachments"; }
  return I18n.t(`upload_selector.${key}`, options);
}

export default Ember.Controller.extend(ModalFunctionality, {
  showMore: false,
  local: true,
  imageUrl: null,
  imageLink: null,
  remote: Ember.computed.not("local"),

  @computed
  uploadIcon() {
    return allowsAttachments() ? "upload" : "picture-o";
  },

  @computed('controller.local')
  tip(local) {
    const source = local ? "local" : "remote";
    const authorized_extensions = authorizesAllExtensions() ? "" : `(${authorizedExtensions()})`;
    return uploadTranslate(`${source}_tip`, { authorized_extensions });
  },

  actions: {
    upload() {
      if (this.get('local')) {
        $('.wmd-controls').fileupload('add', { fileInput: $('#filename-input') });
      } else {
        const imageUrl = this.get('imageUrl') || '';
        const imageLink = this.get('imageLink') || '';
        const toolbarEvent = this.get('toolbarEvent');

        if (this.get('showMore') && imageLink.length > 3) {
          toolbarEvent.addText(`[![](${imageUrl})](${imageLink})`);
        } else {
          toolbarEvent.addText(imageUrl);
        }
      }
      this.send('closeModal');
    },

    useLocal() {
      this.setProperties({ local: true, showMore: false});
    },
    useRemote() {
      this.set("local", false);
    },
    toggleShowMore() {
      this.toggleProperty("showMore");
    }
  }

});
