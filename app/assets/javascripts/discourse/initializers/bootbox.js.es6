/**
  Default settings for bootbox
**/
export default {
  name: "bootbox",
  initialize: function() {
    bootbox.animate(false);

    // clicking outside a bootbox modal closes it
    bootbox.backdrop(true);
  }
};
