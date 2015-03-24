function applicable() {

  // CriOS is Chrome on iPad / iPhone, OPiOS is Opera (they need no patching)
  // Dolphin has a wierd user agent, rest seem a bit nitch
  return navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
         navigator.userAgent.match(/Safari/g) &&
         !navigator.userAgent.match(/CriOS/g) &&
         !navigator.userAgent.match(/OPiOS/g);
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  if (!applicable()) {
    return;
  }

  const fixedElement = $fixedElement[0];


  var positioningHack = function(evt){

    const self = this;

    if (fixedElement.style.position !== 'absolute') {
      evt.preventDefault();
      fixedElement.style.position = 'absolute';
      fixedElement.style.top = (window.scrollY + $('.d-header').height() + 10) + 'px';
    }

    var blurred = function() {
      if (_.include($(document.activeElement).parents(), fixedElement)) {
        // something in focus so skip
        return;
      }
      fixedElement.style.position = '';
      fixedElement.style.top = '';
      self.removeEventListener('blur', blurred);
    };

    blurred = _.debounce(blurred, 300);

    if (this !== document.activeElement) {
      self.focus();
    }

    self.addEventListener('blur', blurred);
  };

  const checkForInputs = _.debounce(function(){
    $fixedElement.find('input,textarea').each(function(){
      if (!$(this).data('listening')) {
        this.addEventListener('touchstart', positioningHack);
        $(this).data('listening', true);
      }
    });
  }, 100);

  fixedElement.addEventListener('DOMNodeInserted', checkForInputs);
}

export default positioningWorkaround;
