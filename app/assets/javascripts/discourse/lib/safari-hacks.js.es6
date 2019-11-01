import { later } from "@ember/runloop";
import debounce from "discourse/lib/debounce";
import {
  safariHacksDisabled,
  iOSWithVisualViewport
} from "discourse/lib/utilities";

// TODO: remove calcHeight once iOS 13 adoption > 90%
// In iOS 13 and up we use visualViewport API to calculate height

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

    // iPhone Xs Max and iPhone Xʀ
    if (window.screen.height === 896) {
      withoutKeyboard = smallViewport ? 410 : 440;
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

export function isWorkaroundActive() {
  return workaroundActive;
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  const caps = Discourse.__container__.lookup("capabilities:main");

  if (!caps.isIOS || safariHacksDisabled()) {
    return;
  }

  const fixedElement = $fixedElement[0];
  const oldHeight = fixedElement.style.height;

  var originalScrollTop = 0;
  let lastTouchedElement = null;

  positioningWorkaround.blur = function(evt) {
    if (workaroundActive) {
      $("body").removeClass("ios-safari-composer-hacks");

      if (!iOSWithVisualViewport()) {
        fixedElement.style.height = oldHeight;
        later(() => $(fixedElement).removeClass("no-transition"), 500);
      }

      $(window).scrollTop(originalScrollTop);

      if (evt) {
        evt.target.removeEventListener("blur", blurred);
      }
      workaroundActive = false;
    }
  };

  var blurredNow = function(evt) {
    // we cannot use evt.relatedTarget to get the last focused element in safari iOS
    // document.activeElement is also unreliable (iOS does not mark buttons as focused)
    // so instead, we store the last touched element and check against it

    if (
      lastTouchedElement &&
      ($(lastTouchedElement).hasClass("select-kit-header") ||
        $(lastTouchedElement).closest(".autocomplete").length ||
        ["span", "svg", "button"].includes(
          lastTouchedElement.nodeName.toLowerCase()
        ))
    ) {
      return;
    }

    positioningWorkaround.blur(evt);
  };

  var blurred = debounce(blurredNow, 250);

  var positioningHack = function(evt) {
    // we need this, otherwise changing focus means we never clear
    this.addEventListener("blur", blurred);

    // resets focus out of select-kit elements
    // might become redundant after select-kit refactoring
    $fixedElement.find(".select-kit.is-expanded > button").trigger("click");
    $fixedElement
      .find(".select-kit > button.is-focused")
      .removeClass("is-focused");

    if ($(window).scrollTop() > 0) {
      originalScrollTop = $(window).scrollTop();
    }

    setTimeout(function() {
      if (iOSWithVisualViewport()) {
        // disable hacks when using a hardware keyboard
        // by default, a hardware keyboard will show the keyboard accessory bar
        // whose height is currently 55px (using 75 for a bit of a buffer)
        let heightDiff = window.innerHeight - window.visualViewport.height;
        if (heightDiff < 75) {
          return;
        }
      }

      if (fixedElement.style.top === "0px") {
        if (this !== document.activeElement) {
          evt.preventDefault();

          // this tricks safari into assuming current input is at top of the viewport
          // via https://stackoverflow.com/questions/38017771/mobile-safari-prevent-scroll-page-when-focus-on-input
          this.style.transform = "translateY(-200px)";
          this.focus();
          let _this = this;
          setTimeout(function() {
            _this.style.transform = "none";
          }, 30);
        }
        return;
      }

      // don't trigger keyboard on disabled element (happens when a category is required)
      if (this.disabled) {
        return;
      }

      $("body").addClass("ios-safari-composer-hacks");
      $(window).scrollTop(0);

      let i = 20;
      let interval = setInterval(() => {
        $(window).scrollTop(0);
        if (i-- === 0) {
          clearInterval(interval);
        }
      }, 10);

      if (!iOSWithVisualViewport()) {
        const height = calcHeight();
        fixedElement.style.height = height + "px";
        $(fixedElement).addClass("no-transition");
      }

      evt.preventDefault();
      this.focus();
      workaroundActive = true;
    }, 350);
  };

  var lastTouched = function(evt) {
    if (evt && evt.target) {
      lastTouchedElement = evt.target;
    }
  };

  function attachTouchStart(elem, fn) {
    if (!$(elem).data("listening")) {
      elem.addEventListener("touchstart", fn);
      $(elem).data("listening", true);
    }
  }

  const checkForInputs = debounce(function() {
    attachTouchStart(fixedElement, lastTouched);

    $fixedElement.find("input[type=text],textarea").each(function() {
      attachTouchStart(this, positioningHack);
    });
  }, 100);

  const config = {
    childList: true,
    subtree: true,
    attributes: false,
    characterData: false
  };
  const observer = new MutationObserver(checkForInputs);
  observer.observe(fixedElement, config);
}

export default positioningWorkaround;
