import { isAppleDevice } from "discourse/lib/utilities";

// we can't tell what the actual visible window height is
// because we cannot account for the height of the mobile keyboard
// and any other mobile autocomplete UI that may appear
// so let's be conservative here rather than trying to max out every
// available pixel of height for the editor
function calcHeight() {
  // estimate 270 px for keyboard
  let withoutKeyboard = window.innerHeight - 270;
  const min = 270;

  // iPhone shrinks header and removes footer controls ( back / forward nav )
  // at 39px we are at the largest viewport
  const portrait = window.innerHeight > window.innerWidth;
  const smallViewport =
    (portrait ? window.screen.height : window.screen.width) -
      window.innerHeight >
    40;

  if (portrait) {
    // iPhone SE, it is super small so just
    // have a bit of crop
    if (window.screen.height === 568) {
      withoutKeyboard = 270;
    }

    // iPhone 6/7/8
    if (window.screen.height === 667) {
      withoutKeyboard = smallViewport ? 295 : 325;
    }

    // iPhone 6/7/8 plus
    if (window.screen.height === 736) {
      withoutKeyboard = smallViewport ? 353 : 383;
    }

    // iPhone X
    if (window.screen.height === 812) {
      withoutKeyboard = smallViewport ? 340 : 370;
    }

    // iPad can use innerHeight cause it renders nothing in the footer
    if (window.innerHeight > 920) {
      withoutKeyboard -= 45;
    }
  } else {
    // landscape
    // iPad, we have a bigger keyboard
    if (window.innerHeight > 665) {
      withoutKeyboard -= 128;
    }
  }

  // iPad portrait also has a bigger keyboard
  return Math.max(withoutKeyboard, min);
}

let workaroundActive = false;
let composingTopic = false;

export function isWorkaroundActive() {
  return workaroundActive;
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  if (!isAppleDevice()) {
    return;
  }

  const fixedElement = $fixedElement[0];
  const oldHeight = fixedElement.style.height;

  var done = false;
  var originalScrollTop = 0;

  positioningWorkaround.blur = function(evt) {
    if (workaroundActive) {
      done = true;

      $("#main-outlet").show();
      $("header").show();

      fixedElement.style.position = "";
      fixedElement.style.top = "";
      fixedElement.style.height = oldHeight;

      Ember.run.later(() => $(fixedElement).removeClass("no-transition"), 500);

      $(window).scrollTop(originalScrollTop);

      if (evt) {
        evt.target.removeEventListener("blur", blurred);
      }
      workaroundActive = false;
    }
  };

  var blurredNow = function(evt) {
    if (!done && _.include($(document.activeElement).parents(), fixedElement)) {
      // something in focus so skip
      return;
    }

    positioningWorkaround.blur(evt);
  };

  var blurred = _.debounce(blurredNow, 250);

  var positioningHack = function(evt) {
    const self = this;
    done = false;

    // we need this, otherwise changing focus means we never clear
    self.addEventListener("blur", blurred);

    if (fixedElement.style.top === "0px") {
      if (this !== document.activeElement) {
        evt.preventDefault();
        self.focus();
      }
      return;
    }

    originalScrollTop = $(window).scrollTop();

    // take care of body

    $("#main-outlet").hide();
    $("header").hide();

    $(window).scrollTop(0);

    let i = 20;
    let interval = setInterval(() => {
      $(window).scrollTop(0);
      if (i-- === 0) {
        clearInterval(interval);
      }
    }, 10);

    fixedElement.style.top = "0px";

    composingTopic = $("#reply-control .category-chooser").length > 0;

    const height = calcHeight(composingTopic);
    fixedElement.style.height = height + "px";

    $(fixedElement).addClass("no-transition");

    evt.preventDefault();
    self.focus();
    workaroundActive = true;
  };

  function attachTouchStart(elem, fn) {
    if (!$(elem).data("listening")) {
      elem.addEventListener("touchstart", fn);
      $(elem).data("listening", true);
    }
  }

  const checkForInputs = _.debounce(function() {
    $fixedElement
      .find(
        "button:not(.hide-preview),a:not(.mobile-file-upload):not(.toggle-toolbar)"
      )
      .each(function(idx, elem) {
        if ($(elem).parents(".emoji-picker").length > 0) {
          return;
        }

        if ($(elem).parents(".autocomplete").length > 0) {
          return;
        }

        if ($(elem).parents(".d-editor-button-bar").length > 0) {
          return;
        }

        attachTouchStart(this, function(evt) {
          done = true;
          $(document.activeElement).blur();
          evt.preventDefault();
          $(this).click();
        });
      });
    $fixedElement.find("input[type=text],textarea").each(function() {
      attachTouchStart(this, positioningHack);
    });
  }, 100);

  fixedElement.addEventListener("DOMNodeInserted", checkForInputs);
}

export default positioningWorkaround;
