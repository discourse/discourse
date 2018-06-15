function _clean() {
  if (window.MiniProfiler) {
    window.MiniProfiler.pageTransition();
  }

  // Close some elements that may be open
  $("header ul.icons li").removeClass("active");
  $('[data-toggle="dropdown"]')
    .parent()
    .removeClass("open");
  // close the lightbox
  if ($.magnificPopup && $.magnificPopup.instance) {
    $.magnificPopup.instance.close();
    $("body").removeClass("mfp-zoom-out-cur");
  }

  // Remove any link focus
  // NOTE: the '.not("body")' is here to prevent a bug in IE10 on Win7
  // cf. https://stackoverflow.com/questions/5657371
  $(document.activeElement)
    .not("body")
    .not(".no-blur")
    .blur();

  Discourse.set("notifyCount", 0);
  Discourse.__container__.lookup("route:application").send("closeModal");
  const hideDropDownFunction = $("html").data("hide-dropdown");
  if (hideDropDownFunction) {
    hideDropDownFunction();
  }

  // TODO: Avoid container lookup here
  const appEvents = Discourse.__container__.lookup("app-events:main");
  appEvents.trigger("dom:clean");
}

export function cleanDOM() {
  Ember.run.scheduleOnce("afterRender", _clean);
}
