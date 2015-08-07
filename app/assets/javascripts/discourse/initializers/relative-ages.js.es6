import { updateRelativeAge } from 'discourse/lib/formatter';

// Updates the relative ages of dates on the screen.
export default {
  name: "relative-ages",
  initialize: function() {
    setInterval(function(){
      updateRelativeAge($('.relative-date'));
    }, 60 * 1000);
  }
};
