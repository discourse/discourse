import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { helperContext } from "discourse-common/lib/helpers";
import { later } from "@ember/runloop";

let workaroundActive = false;

export function isWorkaroundActive() {
  return workaroundActive;
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  let caps = helperContext().capabilities;
  if (!caps.isIOS) {
    return;
  }

  document.addEventListener("scroll", () => {
    if (!caps.isIpadOS && workaroundActive) {
      window.scrollTo(0, 0);
    }
  });

  const fixedElement = $fixedElement[0];
  let originalScrollTop = 0;
  let lastTouchedElement = null;

  positioningWorkaround.blur = function (evt) {
    if (workaroundActive) {
      document.body.classList.remove("ios-safari-composer-hacks");
      window.scrollTo(0, originalScrollTop);

      if (evt && evt.target) {
        evt.target.removeEventListener("blur", blurred);
      }

      workaroundActive = false;
    }
  };

  let blurredNow = function (evt) {
    // we cannot use evt.relatedTarget to get the last focused element in safari iOS
    // document.activeElement is also unreliable (iOS does not mark buttons as focused)
    // so instead, we store the last touched element and check against it

    // cancel blur event when:
    // - switching to another iOS app
    // - displaying title field
    // - invoking a select-kit dropdown
    // - invoking mentions
    // - invoking emoji dropdown via : and hitting return
    // - invoking a button in the editor toolbar
    // - tapping on emoji in the emoji modal

    if (
      lastTouchedElement &&
      (document.visibilityState === "hidden" ||
        $fixedElement.hasClass("edit-title") ||
        $(lastTouchedElement).hasClass("select-kit-header") ||
        $(lastTouchedElement).closest(".autocomplete").length ||
        (lastTouchedElement.nodeName.toLowerCase() === "textarea" &&
          document.activeElement === lastTouchedElement) ||
        $(lastTouchedElement).closest(".d-editor-button-bar").length ||
        $(lastTouchedElement).hasClass("emoji"))
    ) {
      return;
    }

    positioningWorkaround.blur(evt);
  };

  let blurred = function (evt) {
    discourseDebounce(this, blurredNow, evt, INPUT_DELAY);
  };

  let positioningHack = function (evt) {
    let _this = this;

    if (evt === undefined) {
      evt = new CustomEvent("no-op");
    }

    // we need this, otherwise changing focus means we never clear
    this.addEventListener("blur", blurred);

    // resets focus out of select-kit elements
    // might become redundant after select-kit refactoring
    $fixedElement.find(".select-kit.is-expanded > button").trigger("click");
    $fixedElement
      .find(".select-kit > button.is-focused")
      .removeClass("is-focused");

    if (window.pageYOffset > 0) {
      originalScrollTop = window.pageYOffset;
    }

    let delay = caps.isIpadOS ? 350 : 150;

    later(() => {
      if (caps.isIpadOS) {
        // disable hacks when using a hardware keyboard
        // by default, a hardware keyboard will show the keyboard accessory bar
        // whose height is currently 55px (using 75 for a bit of a buffer)
        let heightDiff = window.innerHeight - window.visualViewport.height;
        if (heightDiff < 75) {
          return;
        }
      }

      // don't trigger keyboard on disabled element (happens when a category is required)
      if (_this.disabled) {
        return;
      }

      document.body.classList.add("ios-safari-composer-hacks");
      window.scrollTo(0, 0);

      evt.preventDefault();
      _this.focus();
      workaroundActive = true;
    }, delay);
  };

  let lastTouched = function (evt) {
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

  const checkForInputs = function () {
    discourseDebounce(
      this,
      function () {
        attachTouchStart(fixedElement, lastTouched);

        $fixedElement.find("input[type=text],textarea").each(function () {
          attachTouchStart(this, positioningHack);
        });
      },
      100
    );
  };

  positioningWorkaround.touchstartEvent = function (element) {
    let triggerHack = positioningHack.bind(element);
    triggerHack();
  };

  const config = {
    childList: true,
    subtree: true,
    attributes: false,
    characterData: false,
  };
  const observer = new MutationObserver(checkForInputs);
  observer.observe(fixedElement, config);
}

export default positioningWorkaround;
