(function() {

  window.Discourse.Presence = Em.Mixin.create({
    /* Is a property blank?
    */

    blank: function(name) {
      var prop;
      prop = this.get(name);
      if (!prop) {
        return true;
      }
      switch (typeof prop) {
        case "string":
          return prop.trim().isBlank();
        case "object":
          return Object.isEmpty(prop);
      }
      return false;
    },
    present: function(name) {
      return !this.blank(name);
    }
  });

}).call(this);
