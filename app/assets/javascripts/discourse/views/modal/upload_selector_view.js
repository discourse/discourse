/**
  This view handles the upload interface

  @class UploadSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/

function uploadTranslate(key, options) {
  var opts = options || {};
  if (Discourse.Utilities.allowsAttachments()) { key += "_with_attachments"; }
  return I18n.t("upload_selector." + key, opts);
}

Discourse.UploadSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/upload_selector',
  classNames: ['upload-selector'],

  title: function() { return uploadTranslate("title"); }.property(),
  uploadIcon: function() { return Discourse.Utilities.allowsAttachments() ? "fa-upload" : "fa-picture-o"; }.property(),

  tip: function() {
    var source = this.get("controller.local") ? "local" : "remote";
    var opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return uploadTranslate(source + "_tip", opts);
  }.property("controller.local"),

  hint: function() {
    // cf. http://stackoverflow.com/a/9851769/11983
    var isChrome = !!window.chrome && !(!!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0);
    var isFirefox = typeof InstallTrigger !== 'undefined';
    var isSupported = isChrome || isFirefox;

    // chrome is the only browser that support copy & paste of images.
    return I18n.t("upload_selector.hint" + (isSupported ? "_for_supported_browsers" : ""));
  }.property(),

  didInsertElement: function() {
    this._super();
    this.selectedChanged();
  },

  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      // *HACK* to select the proper radio button
      var value = self.get('controller.local') ? 'local' : 'remote';
      $('input:radio[name="upload"]').val([value]);
      // focus the input
      $('.inputs input:first').focus();
    });
  }.observes('controller.local'),

  actions: {
    upload: function() {
      if (this.get("controller.local")) {
        $('#reply-control').fileupload('add', { fileInput: $('#filename-input') });
      } else {
        var imageUrl = $('#fileurl-input').val();
        var imageLink = $('#link-input').val();
        var composerView = this.get('controller.composerView');
        if (this.get("controller.showMore") && imageLink.length > 3) {
          composerView.addMarkdown("[![](" + imageUrl +")](" + imageLink + ")");
        } else {
          composerView.addMarkdown(imageUrl);
        }
        this.get('controller').send('closeModal');
      }
    }
  }

});
