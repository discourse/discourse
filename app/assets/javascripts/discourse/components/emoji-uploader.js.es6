import { displayErrorForUpload } from 'discourse/lib/utilities';
import { default as computed, on } from "ember-addons/ember-computed-decorators";
import UploadMixin from "discourse/mixins/upload";

export default Em.Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",

  hasName: Em.computed.notEmpty("name"),
  addDisabled: Em.computed.not("hasName"),

  @on("init")
  _subscribeToEmojiUploads() {
    this.messageBus.subscribe("/uploads/emoji", upload => {
      if (upload && upload.url) {
        this.sendAction("done", upload);
      } else {
        displayErrorForUpload(upload);
      }
    });
  },

  @on("willDestroyElement")
  _unsubscribeFromEmojiUploads() {
    this.messageBus.unsubscribe("/uploads/emoji");
  },

  @computed("name")
  data(name) {
    return Ember.isBlank(name) ? {} : { name };
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone() {
    this.set("name", null);
  }
});
