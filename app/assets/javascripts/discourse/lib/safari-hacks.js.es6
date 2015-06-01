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

  var done = false;

  var blurredNow = function(evt) {
    if (!done && _.include($(document.activeElement).parents(), fixedElement)) {
      // something in focus so skip
      return;
    }

    done = true;
    fixedElement.style.position = '';
    fixedElement.style.top = '';
    if (evt) {
      evt.target.removeEventListener('blur', blurred);
    }
  };

  var blurred = _.debounce(blurredNow, 250);

  var positioningHack = function(evt){

    const self = this;
    done = false;

    // we need this, otherwise changing focus means we never clear
    self.addEventListener('blur', blurred);

    if (fixedElement.style.position === 'absolute') {
      if (this !== document.activeElement) {
        evt.preventDefault();
        self.focus();
      }
      return;
    }

    fixedElement.style.position = 'absolute';
    // get out of the way while opening keyboard
    fixedElement.style.top = '0px';

    var iPadOffset = 0;
    if (window.innerHeight > window.innerWidth && navigator.userAgent.match(/iPad/)) {
      // there is no way to get virtual keyboard height
      iPadOffset = 640 - $(fixedElement).height();
    }

    var oldScrollY = 0;

    var positionElement = function(){
      if (done) {
        return;
      }
      if (Math.abs(oldScrollY - window.scrollY) < 20) {
        return;
      }
      oldScrollY = window.scrollY;
      fixedElement.style.top = window.scrollY + iPadOffset + 'px';
    };

    // position once, correctly, after keyboard is shown
    setTimeout(positionElement, 500);

    evt.preventDefault();
    self.focus();
  };

  function attachTouchStart(elem, fn) {
    if (!$(elem).data('listening')) {
        elem.addEventListener('touchstart', fn);
        $(elem).data('listening', true);
    }
  }

  const checkForInputs = _.debounce(function(){
    $fixedElement.find('button,a').each(function(){
      attachTouchStart(this, function(evt){
        done = true;
        $(document.activeElement).blur();
        evt.preventDefault();
        $(this).click();
      });
    });
    $fixedElement.find('input,textarea').each(function(){
      attachTouchStart(this, positioningHack);
    });
  }, 100);

  fixedElement.addEventListener('DOMNodeInserted', checkForInputs);
}

export default positioningWorkaround;
