// hacks for ember, this sets up our app for testing

(function(){

  var currentWindowOnload = window.onload;
  window.onload = function() {
    if (currentWindowOnload) {
      currentWindowOnload();
    }
    
    jQuery('<div id="main"><div class="rootElement"></div></div>').appendTo(jQuery('body')).hide();

    Discourse.SiteSettings = {}

    Discourse.Router.map(function() {
      this.route("jasmine",{path: "/jasmine"});
      Discourse.routeBuilder.apply(this)
    });
  }

})()
