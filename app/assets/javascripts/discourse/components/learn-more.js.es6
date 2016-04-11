export default Ember.Component.extend({
  type: null,

  uploadInfo(type){
    $.ajax({
      url: '/uploads-info',
      success: function(data){
        bootbox.alert(I18n.t("learn_more." + type, { max_size: data[type] }))
    }});
  },

  actions: {
    show(){
      switch(this.get('type')){
        case 'max_image_size':
          this.uploadInfo(this.get('type'));
          break;
        default:
          console.log('Not found')
      }
    }
  }
})
