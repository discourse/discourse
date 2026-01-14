/**
 * tua-body-scroll-lock v1.6.0
 * (c) 2025 Evinma, BuptStEve
 * @license MIT
 */

const isServer = () => typeof window === "undefined";
const detectOS = (ua) => {
  ua = ua || navigator.userAgent;
  const ipad = /(iPad).*OS\s([\d_]+)/.test(ua);
  const iphone = !ipad && /(iPhone\sOS)\s([\d_]+)/.test(ua);
  const android = /(Android);?[\s/]+([\d.]+)?/.test(ua);
  const ios = iphone || ipad;
  return { ios, android };
};
function getEventListenerOptions(options) {
  /* istanbul ignore if */
  if (isServer()) {
    return false;
  }
  if (!options) {
    throw new Error("options must be provided");
  }
  let isSupportOptions = false;
  const listenerOptions = {
    get passive() {
      isSupportOptions = true;
      return undefined;
    },
  };
  const noop = () => {};
  const testEvent = "__TUA_BSL_TEST_PASSIVE__";
  window.addEventListener(testEvent, noop, listenerOptions);
  window.removeEventListener(testEvent, noop, listenerOptions);
  const { capture } = options;
  /* istanbul ignore next */
  return isSupportOptions
    ? options
    : typeof capture !== "undefined"
      ? capture
      : false;
}
function noticeRequiredTargetElement(targetElement) {
  if (targetElement) {
    return false;
  }
  if (targetElement === null) {
    return false;
  }
  return true;
}

function getPreventEventDefault() {
  if ("__BSL_PREVENT_DEFAULT__" in window) {
    return window.__BSL_PREVENT_DEFAULT__;
  }
  window.__BSL_PREVENT_DEFAULT__ = function (event) {
    if (!event.cancelable) {
      return;
    }
    event.preventDefault();
  };
  return window.__BSL_PREVENT_DEFAULT__;
}
function toArray(x) {
  if (!x) {
    return [];
  }
  return Array.isArray(x) ? x : [x];
}

const initialLockState = {
  lockedNum: 0,
  lockedElements: [],
  unLockCallback: null,
  documentListenerAdded: false,
  initialClientPos: {
    clientX: 0,
    clientY: 0,
  },
};
/**
 * get current lockState
 * @param options
 * @returns lockState
 */
function getLockState(options) {
  if (isServer()) {
    return initialLockState;
  }
  /** use local lockState */
  if (
    !(options === null || options === void 0
      ? void 0
      : options.useGlobalLockState)
  ) {
    return getLockState.lockState;
  }
  /** use global lockState */
  const lockState =
    "__BSL_LOCK_STATE__" in window
      ? Object.assign(
          Object.assign({}, initialLockState),
          window.__BSL_LOCK_STATE__
        )
      : initialLockState;
  /** assign to global */
  window.__BSL_LOCK_STATE__ = lockState;
  return lockState;
}
getLockState.lockState = initialLockState;

function handleScroll(
  event,
  targetElement,
  initialClientPos,
  options = {
    reverseColumn: false,
    reverseRow: false,
  }
) {
  if (targetElement) {
    const {
      scrollTop,
      scrollLeft,
      scrollWidth,
      scrollHeight,
      clientWidth,
      clientHeight,
    } = targetElement;
    const { reverseColumn = false, reverseRow = false } = options;
    const clientX = event.targetTouches[0].clientX - initialClientPos.clientX;
    const clientY = event.targetTouches[0].clientY - initialClientPos.clientY;
    const isVertical = Math.abs(clientY) > Math.abs(clientX);
    let isOnTop, isOnBottom, isOnLeft, isOnRight;
    if (reverseColumn) {
      isOnTop = clientY > 0 && scrollTop + clientHeight + 1 >= scrollHeight;
      isOnBottom = clientY < 0 && scrollTop === 0;
    } else {
      isOnTop = clientY > 0 && scrollTop === 0;
      isOnBottom = clientY < 0 && scrollTop + clientHeight + 1 >= scrollHeight;
    }
    if (reverseRow) {
      isOnLeft = clientX > 0 && scrollLeft + clientWidth + 1 >= scrollWidth;
      isOnRight = clientX < 0 && scrollLeft === 0;
    } else {
      isOnLeft = clientX > 0 && scrollLeft === 0;
      isOnRight = clientX < 0 && scrollLeft + clientWidth + 1 >= scrollWidth;
    }
    if (
      (isVertical && (isOnTop || isOnBottom)) ||
      (!isVertical && (isOnLeft || isOnRight))
    ) {
      return getPreventEventDefault()(event);
    }
  }
  event.stopPropagation();
  return true;
}

function setOverflowForPc() {
  const $html = document.documentElement;
  const htmlStyle = Object.assign({}, $html.style);
  const withPaddingRight = true;
  $html.style.overflow = "hidden";
  $html.style.boxSizing = "border-box";
  if (withPaddingRight) {
    const scrollBarWidth = window.innerWidth - $html.clientWidth;
    const previousPaddingRight = parseInt(
      window.getComputedStyle($html).paddingRight,
      10
    );
    $html.style.paddingRight = `${scrollBarWidth + previousPaddingRight}px`;
  }
  return () => {
    ["overflow", "boxSizing", "paddingRight"].forEach((x) => {
      $html.style[x] = htmlStyle[x] || "";
    });
  };
}
function setOverflowForMobile(options) {
  const $html = document.documentElement;
  const $body = document.body;
  const scrollTop = $html.scrollTop || $body.scrollTop;
  const htmlStyle = Object.assign({}, $html.style);
  const bodyStyle = Object.assign({}, $body.style);
  $html.style.height = "100%";
  $html.style.overflow = "hidden";
  $body.style.top = `-${scrollTop}px`;
  $body.style.width = "100%";
  $body.style.height = "auto";
  $body.style.position = "fixed";
  $body.style.overflow =
    (options === null || options === void 0 ? void 0 : options.overflowType) ||
    "hidden";
  return () => {
    $html.style.height = htmlStyle.height || "";
    $html.style.overflow = htmlStyle.overflow || "";
    ["top", "width", "height", "overflow", "position"].forEach((x) => {
      $body.style[x] = bodyStyle[x] || "";
    });
    const supportsNativeSmoothScroll =
      "scrollBehavior" in document.documentElement.style;
    if (supportsNativeSmoothScroll) {
      window.scrollTo({ top: scrollTop, behavior: "instant" });
    } else {
      window.scrollTo(0, scrollTop);
    }
  };
}

/**
 * lock body scroll
 * @param targetElement the element(s) still needs scrolling（iOS only）
 * @param options
 */
function lock(targetElement, options) {
  if (isServer()) {
    return;
  }
  noticeRequiredTargetElement(targetElement);
  const detectRes = detectOS();
  const lockState = getLockState(options);
  if (detectRes.ios) {
    toArray(targetElement)
      .filter((e) => e && lockState.lockedElements.indexOf(e) === -1)
      .forEach((element) => {
        element.ontouchstart = (event) => {
          const { clientX, clientY } = event.targetTouches[0];
          lockState.initialClientPos = { clientX, clientY };
        };
        element.ontouchmove = (event) => {
          handleScroll(event, element, lockState.initialClientPos, {
            reverseRow:
              options === null || options === void 0
                ? void 0
                : options.reverseRow,
            reverseColumn:
              options === null || options === void 0
                ? void 0
                : options.reverseColumn,
          });
        };
        lockState.lockedElements.push(element);
      });
    addTouchMoveListener(lockState);
    if (
      options === null || options === void 0
        ? void 0
        : options.setOverflowForIOS
    ) {
      lockState.unLockCallback = setOverflowForPc();
    }
  } else if (lockState.lockedNum <= 0) {
    lockState.unLockCallback = detectRes.android
      ? setOverflowForMobile(options)
      : setOverflowForPc();
  }
  lockState.lockedNum += 1;
}
/**
 * unlock body scroll
 * @param targetElement the element(s) still needs scrolling（iOS only）
 * @param options
 */
function unlock(targetElement, options) {
  let _a;
  if (isServer()) {
    return;
  }
  noticeRequiredTargetElement(targetElement);
  const lockState = getLockState(options);
  lockState.lockedNum -= 1;
  if (lockState.lockedNum > 0) {
    return;
  }
  (_a = lockState.unLockCallback) === null || _a === void 0
    ? void 0
    : _a.call(lockState);
  if (!detectOS().ios) {
    return;
  }
  toArray(targetElement).forEach((element) => {
    const index = lockState.lockedElements.indexOf(element);
    if (element && index !== -1) {
      element.ontouchmove = null;
      element.ontouchstart = null;
      lockState.lockedElements.splice(index, 1);
    }
  });
  removeTouchMoveListener(lockState);
}
/**
 * clear all body locks
 * @param options
 */
function clearBodyLocks(options) {
  let _a;
  if (isServer()) {
    return;
  }
  const lockState = getLockState(options);
  lockState.lockedNum = 0;
  (_a = lockState.unLockCallback) === null || _a === void 0
    ? void 0
    : _a.call(lockState);
  if (!detectOS().ios) {
    return;
  }
  if (lockState.lockedElements.length) {
    let element = lockState.lockedElements.pop();
    while (element) {
      element.ontouchmove = null;
      element.ontouchstart = null;
      element = lockState.lockedElements.pop();
    }
  }
  removeTouchMoveListener(lockState);
}
function addTouchMoveListener(lockState) {
  if (!detectOS().ios) {
    return;
  }
  if (lockState.documentListenerAdded) {
    return;
  }
  document.addEventListener(
    "touchmove",
    getPreventEventDefault(),
    getEventListenerOptions({ passive: false })
  );
  lockState.documentListenerAdded = true;
}
function removeTouchMoveListener(lockState) {
  if (!lockState.documentListenerAdded) {
    return;
  }
  document.removeEventListener(
    "touchmove",
    getPreventEventDefault(),
    getEventListenerOptions({ passive: false })
  );
  lockState.documentListenerAdded = false;
}

export { clearBodyLocks, getLockState, lock, unlock };
