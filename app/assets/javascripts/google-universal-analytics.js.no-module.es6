/* eslint-disable */
// prettier-ignore
(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
/* eslint-enable */

(function() {
  const gaDataElement = document.getElementById("data-ga-universal-analytics");
  const gaJson = JSON.parse(gaDataElement.dataset.json);

  window.ga("create", gaDataElement.dataset.trackingCode, gaJson);
  if (gaDataElement.dataset.autoLinkDomains.length) {
    const autoLinkDomains = gaDataElement.dataset.autoLinkDomains.split("|");

    window.ga("require", "linker");
    window.ga("linker:autoLink", autoLinkDomains);
  }
})();
