// discourse-skip-module

document.write(
  '<div id="ember-testing-container"><div id="ember-testing"></div></div>'
);
document.write(
  "<style>#ember-testing-container { position: fixed; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; transform: translateZ(0)} #ember-testing { width: 200%; height: 200%; transform: scale(0.5); transform-origin: top left; }</style>"
);

let setupTestsLegacy = require("discourse/tests/setup-tests").setupTestsLegacy;
setupTestsLegacy(window.Discourse);

const keyFromKeyCode = {
  8: "Backspace",
  9: "Tab",
  13: "Enter",
  16: "Shift",
  17: "Control",
  18: "Alt",
  20: "CapsLock",
  27: "Escape",
  32: " ",
  37: "ArrowLeft",
  38: "ArrowUp",
  39: "ArrowRight",
  40: "ArrowDown",
  48: "0",
  49: "1",
  50: "2",
  51: "3",
  52: "4",
  53: "5",
  54: "6",
  55: "7",
  56: "8",
  57: "9",
  65: "a",
  66: "b",
  67: "c",
  68: "d",
  69: "e",
  70: "f",
  71: "g",
  72: "h",
  73: "i",
  74: "j",
  75: "k",
  76: "l",
  77: "m",
  78: "n",
  79: "o",
  80: "p",
  81: "q",
  82: "r",
  83: "s",
  84: "t",
  85: "u",
  86: "v",
  87: "w",
  88: "x",
  89: "y",
  90: "z",
  91: "Meta",
  93: "Meta",
  97: "a",
  98: "b",
  99: "c",
  100: "d",
  101: "e",
  102: "f",
  103: "g",
  104: "h",
  105: "i",
  106: "j",
  107: "k",
  108: "l",
  109: "m",
  110: "n",
  111: "o",
  112: "p",
  113: "q",
  114: "r",
  115: "s",
  116: "t",
  117: "u",
  118: "v",
  119: "w",
  120: "x",
  121: "y",
  122: "z",
  187: "=",
  189: "-",
};

window.keyEvent = function (selector, contextOrType, typeOrKeyCode, keyCode) {
  let context, type;

  if (keyCode === undefined) {
    context = null;
    keyCode = typeOrKeyCode;
    type = contextOrType;
  } else {
    context = contextOrType;
    type = typeOrKeyCode;
  }

  let key = keyFromKeyCode[keyCode];

  return window.triggerEvent(selector, context, type, {
    keyCode: keyCode,
    which: keyCode,
    key: key,
  });
};
