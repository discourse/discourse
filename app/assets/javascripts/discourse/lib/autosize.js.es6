const set =
  typeof Set === "function"
    ? new Set()
    : (function() {
        const list = [];

        return {
          has(key) {
            return Boolean(list.indexOf(key) > -1);
          },
          add(key) {
            list.push(key);
          },
          delete(key) {
            list.splice(list.indexOf(key), 1);
          }
        };
      })();

function assign(ta, { setOverflowX = true, setOverflowY = true } = {}) {
  if (!ta || !ta.nodeName || ta.nodeName !== "TEXTAREA" || set.has(ta)) return;

  let heightOffset = null;
  let overflowY = null;
  let clientWidth = ta.clientWidth;

  function init() {
    const style = window.getComputedStyle(ta, null);

    overflowY = style.overflowY;

    if (style.resize === "vertical") {
      ta.style.resize = "none";
    } else if (style.resize === "both") {
      ta.style.resize = "horizontal";
    }

    if (style.boxSizing === "content-box") {
      heightOffset = -(
        parseFloat(style.paddingTop) + parseFloat(style.paddingBottom)
      );
    } else {
      heightOffset =
        parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
    }
    // Fix when a textarea is not on document body and heightOffset is Not a Number
    if (isNaN(heightOffset)) {
      heightOffset = 0;
    }

    update();
  }

  function changeOverflow(value) {
    {
      // Chrome/Safari-specific fix:
      // When the textarea y-overflow is hidden, Chrome/Safari do not reflow the text to account for the space
      // made available by removing the scrollbar. The following forces the necessary text reflow.
      const width = ta.style.width;
      ta.style.width = "0px";
      // Force reflow:
      /* jshint ignore:start */
      ta.offsetWidth;
      /* jshint ignore:end */
      ta.style.width = width;
    }

    overflowY = value;

    if (setOverflowY) {
      ta.style.overflowY = value;
    }

    resize();
  }

  function resize() {
    const htmlTop = window.pageYOffset;
    const bodyTop = document.body.scrollTop;
    const originalHeight = ta.style.height;

    ta.style.height = "auto";

    let endHeight = ta.scrollHeight + heightOffset;

    if (ta.scrollHeight === 0) {
      // If the scrollHeight is 0, then the element probably has display:none or is detached from the DOM.
      ta.style.height = originalHeight;
      return;
    }

    ta.style.height = endHeight + "px";

    // used to check if an update is actually necessary on window.resize
    clientWidth = ta.clientWidth;

    // prevents scroll-position jumping
    document.documentElement.scrollTop = htmlTop;
    document.body.scrollTop = bodyTop;
  }

  function update() {
    const startHeight = ta.style.height;

    resize();

    const style = window.getComputedStyle(ta, null);

    if (style.height !== ta.style.height) {
      if (overflowY !== "visible") {
        changeOverflow("visible");
      }
    } else {
      if (overflowY !== "hidden") {
        changeOverflow("hidden");
      }
    }

    if (startHeight !== ta.style.height) {
      const evt = document.createEvent("Event");
      evt.initEvent("autosize:resized", true, false);
      ta.dispatchEvent(evt);
    }
  }

  const pageResize = () => {
    if (ta.clientWidth !== clientWidth) {
      update();
    }
  };

  const destroy = style => {
    window.removeEventListener("resize", pageResize, false);
    ta.removeEventListener("input", update, false);
    ta.removeEventListener("keyup", update, false);
    ta.removeEventListener("autosize:destroy", destroy, false);
    ta.removeEventListener("autosize:update", update, false);
    set.delete(ta);

    Object.keys(style).forEach(key => {
      ta.style[key] = style[key];
    });
  };

  ta.addEventListener("autosize:destroy", destroy, false);

  // IE9 does not fire onpropertychange or oninput for deletions,
  // so binding to onkeyup to catch most of those events.
  // There is no way that I know of to detect something like 'cut' in IE9.
  if ("onpropertychange" in ta && "oninput" in ta) {
    ta.addEventListener("keyup", update, false);
  }

  window.addEventListener("resize", pageResize, false);
  ta.addEventListener("input", update, false);
  ta.addEventListener("autosize:update", update, false);
  set.add(ta);

  if (setOverflowX) {
    ta.style.overflowX = "hidden";
    ta.style.wordWrap = "break-word";
  }

  init();
}

function exportDestroy(ta) {
  if (!(ta && ta.nodeName && ta.nodeName === "TEXTAREA")) return;
  const evt = document.createEvent("Event");
  evt.initEvent("autosize:destroy", true, false);
  ta.dispatchEvent(evt);
}

function exportUpdate(ta) {
  if (!(ta && ta.nodeName && ta.nodeName === "TEXTAREA")) return;
  const evt = document.createEvent("Event");
  evt.initEvent("autosize:update", true, false);
  ta.dispatchEvent(evt);
}

let autosize = (el, options) => {
  if (el) {
    Array.prototype.forEach.call(el.length ? el : [el], x =>
      assign(x, options)
    );
  }
  return el;
};
autosize.destroy = el => {
  if (el) {
    Array.prototype.forEach.call(el.length ? el : [el], exportDestroy);
  }
  return el;
};
autosize.update = el => {
  if (el) {
    Array.prototype.forEach.call(el.length ? el : [el], exportUpdate);
  }
  return el;
};

export default autosize;
