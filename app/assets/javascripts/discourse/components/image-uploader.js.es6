import UploadMixin from 'discourse/mixins/upload';

export default Em.Component.extend(UploadMixin, {
  classNames: ['image-uploader'],

  backgroundStyle: function() {
    const imageUrl = this.get('imageUrl');
    if (Em.isNone(imageUrl)) { return; }

    return ("background-image: url(" + imageUrl + ")").htmlSafe();
  }.property('imageUrl'),

  uploadDone: function(data) {
    this.set('imageUrl', data.result.url);
  },

  actions: {
    trash() {
      this.set('imageUrl', null);

      // Do we want to signal the delete to the server right away?
      if (this.get('instantDelete')) {
        Discourse.ajax(this.get('uploadUrl'), {
          type: 'DELETE',
          data: { image_type: this.get('type') }
        }).then(null, function() {
          bootbox.alert(I18n.t('generic_error'));
        });
      }
    }
  }
});
