/**
  Updates the relative ages of dates on the screen.
**/
export default {
  name: "relative-ages",
  initialize: function() {
    setInterval(function(){
      Discourse.Formatter.updateRelativeAge($('.relative-date'));
    }, 60 * 1000);
  }
};
