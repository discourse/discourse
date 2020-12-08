export default function () {
  const outletSelector = [
    ".above-site-header-outlet",
    ".below-site-header-outlet",
  ];
  // If these outlets have height they impact timeline and usercard positioning

  let outletHeights = 0;

  outletSelector.forEach(function (outletClass) {
    if (document.querySelector(outletClass)) {
      let outlets = document.querySelectorAll(outletClass);
      outlets.forEach((outlet) => {
        if (outlet.offsetHeight) {
          outletHeights += parseInt(outlet.offsetHeight, 10);
        }
      });
    }
  });

  return outletHeights;
}
