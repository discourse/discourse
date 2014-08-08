import autocomplete from 'discourse/lib/autocomplete';

export default {
  name: "jquery-plugins",
  initialize: function() {

    // Settings for bootbox
    bootbox.animate(false);
    bootbox.backdrop(true);

    // Initialize the autocomplete tool
    $.fn.autocomplete = autocomplete;
  }
};
