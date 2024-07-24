// This script is inlined in `_discourse_stylesheet.html.erb
const links = document.getElementsByClassName("async-css-loading");

const processEvent = function (element, eventListenerCallback) {
  element.dataset["processed"] = true;
  element.removeEventListener("error", eventListenerCallback);
  element.removeEventListener("load", eventListenerCallback);
};

[...links].forEach(function (element) {
  const elementProcessEvent = function () {
    return processEvent(element, elementProcessEvent);
  };

  element.addEventListener("error", elementProcessEvent, { once: true });
  element.addEventListener("load", elementProcessEvent, { once: true });
});
