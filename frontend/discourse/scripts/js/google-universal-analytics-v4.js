(function () {
  const gaDataElement = document.getElementById("data-ga-universal-analytics");
  const gaJson = JSON.parse(gaDataElement.dataset.json);
  window.dataLayer = window.dataLayer || [];

  window.gtag = function () {
    window.dataLayer.push(arguments);
  };
  window.gtag("js", new Date());

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

  const config = {
    send_page_view: false,
    autoLinkConfig,
  };

  // config-level parameters apply to every subsequent event on the page,
  // including the virtual page_view events sent on route changes
  if (gaJson.traffic_type) {
    config.traffic_type = gaJson.traffic_type;
  }

  window.gtag("config", gaDataElement.dataset.trackingCode, config);
})();
