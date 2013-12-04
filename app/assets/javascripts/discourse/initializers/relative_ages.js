/**
  Updates the relative ages of dates on the screen.

**/
Discourse.addInitializer(function() {

  setInterval(function(){
    Discourse.Formatter.updateRelativeAge($('.relative-date'));
  }, 60 * 1000);

}, true);

