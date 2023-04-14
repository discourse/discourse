// This script is inlined in `_discourse_splash.html.erb
const DELAY_TARGET = 2000;
const POLLING_INTERVAL = 50;

const splashSvgTemplate = document.querySelector(".splash-svg-template");
const splashTemplateClone = splashSvgTemplate.content.cloneNode(true);
const svgElement = splashTemplateClone.querySelector("svg");

const svgString = new XMLSerializer().serializeToString(svgElement);
const encodedSvg = btoa(svgString);

const splashWrapper = document.querySelector("#d-splash");
const splashImage =
  splashWrapper && splashWrapper.querySelector(".preloader-image");

if (splashImage) {
  splashImage.src = `data:image/svg+xml;base64,${encodedSvg}`;

  const connectStart = performance.timing.connectStart || 0;
  const targetTime = connectStart + DELAY_TARGET;

  let splashInterval;
  let discourseReady;

  const swapSplash = () => {
    splashWrapper &&
      splashWrapper.style.setProperty("--animation-state", "running");
    svgElement && svgElement.style.setProperty("--animation-state", "running");

    const newSvgString = new XMLSerializer().serializeToString(svgElement);
    const newEncodedSvg = btoa(newSvgString);

    splashImage.src = `data:image/svg+xml;base64,${newEncodedSvg}`;

    performance.mark("discourse-splash-visible");

    clearSplashInterval();
  };

  const clearSplashInterval = () => {
    clearInterval(splashInterval);
    splashInterval = null;
  };

  (() => {
    splashInterval = setInterval(() => {
      if (discourseReady) {
        clearSplashInterval();
      }

      if (Date.now() > targetTime) {
        swapSplash();
      }
    }, POLLING_INTERVAL);
  })();

  document.addEventListener(
    "discourse-ready",
    () => {
      discourseReady = true;
      splashWrapper && splashWrapper.remove();
      performance.mark("discourse-splash-removed");
    },
    { once: true }
  );
}
