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
    var done = false;

    // allow for keyboard in iPad portrait
    var iPadOffset = 0;
    if (window.innerHeight > window.innerWidth && navigator.userAgent.match(/iPad/)) {
      // there is no way to get virtual keyboard height
      iPadOffset = 640 - $(fixedElement).height();
    }

    var positionElement = _.debounce(function(){
      if (done) {
        return;
      }
      fixedElement.style.top = window.scrollY + iPadOffset + 'px';
    }, 500);


    if (fixedElement.style.position !== 'absolute') {
      evt.preventDefault();
      fixedElement.style.position = 'absolute';
      // get out of the way while opening keyboard
      fixedElement.style.top = '0px';
    }

    $(window).on('scroll', positionElement);

    var blurred = function() {
      if (_.include($(document.activeElement).parents(), fixedElement)) {
        // something in focus so skip
        return;
      }

      done = true;
      fixedElement.style.position = '';
      fixedElement.style.top = '';
      self.removeEventListener('blur', blurred);
      $(window).off('scroll', positionElement);
    };

    blurred = _.debounce(blurred, 250);

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
