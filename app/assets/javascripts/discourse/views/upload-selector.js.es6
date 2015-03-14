import ModalBodyView from "discourse/views/modal-body";

function uploadTranslate(key, options) {
  const opts = options || {};
  if (Discourse.Utilities.allowsAttachments()) { key += "_with_attachments"; }
  return I18n.t("upload_selector." + key, opts);
}

export default ModalBodyView.extend({
  templateName: 'modal/upload_selector',
  classNames: ['upload-selector'],

  title: function() { return uploadTranslate("title"); }.property(),
  uploadIcon: function() { return Discourse.Utilities.allowsAttachments() ? "fa-upload" : "fa-picture-o"; }.property(),

  tip: function() {
    const source = this.get("controller.local") ? "local" : "remote",
          opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return uploadTranslate(source + "_tip", opts);
  }.property("controller.local"),

  hint: function() {
    // cf. http://stackoverflow.com/a/9851769/11983
    const isChrome = !!window.chrome && !(!!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0),
          isFirefox = typeof InstallTrigger !== 'undefined',
          isSupported = isChrome || isFirefox;
    // chrome is the only browser that support copy & paste of images.
    return I18n.t("upload_selector.hint" + (isSupported ? "_for_supported_browsers" : ""));
  }.property(),

  _selectOnInsert: function() {
    this.selectedChanged();
  }.on('didInsertElement'),

  selectedChanged: function() {
    const self = this;
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
        const imageUrl = $('#fileurl-input').val(),
              imageLink = $('#link-input').val(),
              composerView = this.get('controller.composerView');
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
