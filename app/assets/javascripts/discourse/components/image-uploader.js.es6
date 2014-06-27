import UploadMixin from 'discourse/mixins/upload';

export default Em.Component.extend(UploadMixin, {

  backgroundStyle: function() {
    var imageUrl = this.get('imageUrl');
    if (Em.isNone(imageUrl)) { return; }

    return "background-image: url(" + imageUrl + ")";
  }.property('imageUrl'),

  uploadDone: function(data) {
    this.set('imageUrl', data.result.url);
  },

  deleteDone: function() {
    this.set('imageUrl', null);
  }
});
