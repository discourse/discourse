/**
  This view handles the upload interface

  @class UploadSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.UploadSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/upload_selector',
  classNames: ['upload-selector'],

  title: function() { return Discourse.UploadSelectorController.translate("title"); }.property(),
  uploadIcon: function() { return Discourse.Utilities.allowsAttachments() ? "icon-file-alt" : "icon-picture"; }.property(),

  tip: function() {
    var source = this.get("controller.local") ? "local" : "remote";
    var opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return Discourse.UploadSelectorController.translate(source + "_tip", opts);
  }.property("controller.local"),

  hint: function() {
    // cf. http://stackoverflow.com/a/9851769/11983
    var isChrome = !!window.chrome && !(!!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0);
    // chrome is the only browser that support copy & paste of images.
    return I18n.t("upload_selector.hint" + (isChrome ? "_for_chrome" : ""));
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
        this.get('controller.composerView').addMarkdown($('#fileurl-input').val());
        this.get('controller').send('closeModal');
      }
    }
  }

});
