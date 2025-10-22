(function () {
  const gtmDataElement = document.getElementById("data-google-tag-manager");
  const dataLayerJson = JSON.parse(gtmDataElement.dataset.dataLayer);
  const gtmNonce = gtmDataElement.dataset.nonce;

  // dataLayer declaration needs to precede the container snippet
  // https://developers.google.com/tag-manager/devguide#adding-data-layer-variables-to-a-page
  window.dataLayer = [dataLayerJson];

  /* eslint-disable */
  // prettier-ignore
  (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
  new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
  j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
  'https://www.googletagmanager.com/gtm.js?id='+i+dl;
  j.setAttribute("nonce", gtmNonce);
  f.parentNode.insertBefore(j,f);
  })(window,document,'script','dataLayer',gtmDataElement.dataset.containerId);
  /* eslint-enable */
})();
