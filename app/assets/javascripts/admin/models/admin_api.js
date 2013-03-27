Discourse.AdminApi = Discourse.Model.extend({
  VALID_KEY_LENGTH: 64,

  keyExists: function(){
    var key = this.get('key') || '';
    return key && key.length === this.VALID_KEY_LENGTH;
  }.property('key'), 

  generateKey: function(){
    var _this = this;

    $.ajax(Discourse.getURL('/admin/api/generate_key'),{
      type: 'POST'
      }).success(function(result){
        _this.set('key', result.key); 
      });
  }
});

Discourse.AdminApi.reopenClass({
  find: function(){
    return this.getAjax('/admin/api');
  }
});
