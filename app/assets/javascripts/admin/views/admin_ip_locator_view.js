Discourse.AdminIpLocatorView = Discourse.View.extend({
  templateName: 'admin/templates/ip_locator',
  classNames: ["iplocator"],
  actions: {
    hideBox: function(){
        this.set("showBox", false);
    },
    lookup: function(){
      if (!this.get("location")){
          $.get("http://ipinfo.io/" + this.get("ip"), function(response) {
              this.set("location", response);
          }.bind(this), "jsonp");
      }

      if (!this.get("other_accounts")){
        this.set("other_accounts_loading", true);
        Discourse.ajax("/admin/users/list/active.json", {
                data: {"ip": this.get("ip"),
                       "exclude": this.get("controller.id")
                      }
            }).then(function (users) {
                this.set("other_accounts", users.map(function(u) { return Discourse.AdminUser.create(u);}));
                this.set("other_accounts_loading", false);
            }.bind(this));
      }
      this.set("showBox", true);
    }
  }
});