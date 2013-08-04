Discourse.LoginMethod = Ember.Object.extend({
  title: function(){
    return this.get("titleOverride") || I18n.t("login." + this.get("name") + ".title");
  }.property(),

  message: function(){
    return this.get("messageOverride") || I18n.t("login." + this.get("name") + ".message");
  }.property()
});

// Note, you can add login methods by adding to the list
//  just Em.get("Discourse.LoginMethod.all") and then
//  pushObject for any new methods
Discourse.LoginMethod.reopenClass({
  register: function(method){
    if(this.methods){
      this.methods.pushObject(method);
    } else {
      this.preRegister = this.preRegister || [];
      this.preRegister.push(method);
    }
  },

  all: function(){
    if (this.methods) { return this.methods; }

    var methods = this.methods = Em.A();

    /*
     * enable_google_logins etc.
     * */

    [ "google",
      "facebook",
      "cas",
      "twitter",
      "yahoo",
      "github",
      "persona"
    ].forEach(function(name){
      if(Discourse.SiteSettings["enable_" + name + "_logins"]){

        var params = {name: name};

        if(name === "persona") {
          params.customLogin = function(){
            navigator.id.request();
          };
        }

        if(name === "google") {
          params.frameWidth = 850;
          params.frameHeight = 500;
        }

        methods.pushObject(Discourse.LoginMethod.create(params));
      }
    });

    if (this.preRegister){
      this.preRegister.forEach(function(method){
        methods.pushObject(method);
      });
      delete this.preRegister;
    }
    return methods;
  }.property()
});

