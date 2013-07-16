
Discourse.PermissionType = Discourse.Model.extend({
  description: function(){
    var key = "";

    switch(this.get("id")){
      case 1:
        key = "full";
        break;
      case 2:
        key = "create_post";
        break;
      case 3:
        key = "readonly";
        break;
    }
    return I18n.t("permission_types." + key);
  }.property("id")
});

Discourse.PermissionType.FULL = 1;
Discourse.PermissionType.CREATE_POST = 2;
Discourse.PermissionType.READONLY = 3;
