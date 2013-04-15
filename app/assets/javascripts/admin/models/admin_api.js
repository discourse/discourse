Discourse.AdminApi = Discourse.Model.extend({
  VALID_KEY_LENGTH: 64,

  keyExists: function(){
    var key = this.get('key') || '';
    return key && key.length === this.VALID_KEY_LENGTH;
  }.property('key'),

  generateKey: function(){
    var adminApi = this;
    Discourse.ajax(Discourse.getURL('/admin/api/generate_key'),{type: 'POST'}).then(function (result) {
      adminApi.set('key', result.key);
    });
  },

  regenerateKey: function(){
    alert(Em.String.i18n('not_implemented'));
  }
});

Discourse.AdminApi.reopenClass({
  find: function() {
    return this.getModelAjax('/admin/api');
  }
});
