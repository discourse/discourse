window.onpopstate = function(event) {
  // check if Discourse object exists if not take care of back navigation
  if (event.state && !window.hasOwnProperty("Discourse")) {
    window.location = document.location;
  }
};
