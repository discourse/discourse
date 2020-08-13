export default function() {
  const outlets = [".above-site-header-outlet", ".below-site-header-outlet"];
  // If these outlets have height they impact timeline and usercard positioning

  let outletHeights = 0;

  outlets.forEach(function(outletClass) {
    if (document.querySelector(outletClass)) {
      let outlet = document.querySelectorAll(outletClass);
      for (var i = 0; i < outlet.length; i++) {
        if (outlet[i].offsetHeight) {
          outletHeights += parseInt(outlet[i].offsetHeight, 10);
        }
      }
    }
  });

  return outletHeights;
}
