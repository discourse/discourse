// discourse-skip-module
(function () {
  const gaDataElement = document.getElementById("data-ga-universal-analytics");

  window.dataLayer = window.dataLayer || [];
  function gtag() {
    window.dataLayer.push(arguments);
  }
  gtag("js", new Date());

  let autoLinkConfig = {};

  if (gaDataElement.dataset.autoLinkDomains.length) {
    const autoLinkDomains = gaDataElement.dataset.autoLinkDomains.split("|");
    autoLinkConfig = {
      linker: {
        accept_incoming: true,
        domains: autoLinkDomains,
      },
    };
  }
  gtag("config", gaDataElement.dataset.trackingCode, autoLinkConfig);
})();
