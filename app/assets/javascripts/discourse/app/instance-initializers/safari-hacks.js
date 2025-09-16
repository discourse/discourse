let alreadyInitialized = false;

const WORKAROUND_PROPERTY = "--safari-workaround-offset";

function runWorkaround() {
  let workaroundOffset = window.innerHeight - window.visualViewport.height;
  if (workaroundOffset > 25) {
    // Keyboard is open. Disable workaround
    workaroundOffset = 0;
  }

  const oldValue =
    document.documentElement.style.getPropertyValue(WORKAROUND_PROPERTY);
  const newValue = `${Math.round(workaroundOffset)}px`;

  if (oldValue !== newValue) {
    document.documentElement.style.setProperty(WORKAROUND_PROPERTY, newValue);
  }
}

export default {
  initialize() {
    const ios26 = navigator.userAgent.includes("iPhone\ OS\ 18_6");

    if (!ios26 || alreadyInitialized) {
      return;
    }

    alreadyInitialized = true;

    setInterval(runWorkaround, 100);
  },
};
