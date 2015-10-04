function applicable() {
  // IE has no DOMNodeInserted so can not get this hack despite saying it is like iPhone
  // This will apply hack on all iDevices
  return navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
         navigator.userAgent.match(/Safari/g) &&
         !navigator.userAgent.match(/Trident/g);
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  if (!applicable()) {
    return;
  }

  const fixedElement = $fixedElement[0];

  var done = false;
  var originalScrollTop = 0;

  var blurredNow = function(evt) {
    if (!done && _.include($(document.activeElement).parents(), fixedElement)) {
      // something in focus so skip
      return;
    }

    done = true;

    $('#main-outlet').show();
    $('header').show();

    fixedElement.style.position = '';
    fixedElement.style.top = '';
    fixedElement.style.height = '';

    $(window).scrollTop(originalScrollTop);

    if (evt) {
      evt.target.removeEventListener('blur', blurred);
    }

    $('body').removeData('disable-cloaked-view');
  };

  var blurred = _.debounce(blurredNow, 250);

  var positioningHack = function(evt){

    const self = this;
    done = false;

    // we need this, otherwise changing focus means we never clear
    self.addEventListener('blur', blurred);

    if (fixedElement.style.top === '0px') {
      if (this !== document.activeElement) {
        evt.preventDefault();
        self.focus();
      }
      return;
    }

    originalScrollTop = $(window).scrollTop();

    // take care of body

    $('body').data('disable-cloaked-view',true);
    $('#main-outlet').hide();
    $('header').hide();

    $(window).scrollTop(0);

    fixedElement.style.top = '0px';

    fixedElement.style.height = parseInt(window.innerHeight*0.6) + "px";

    // I used to do this, but it seems like we don't need to with position
    // fixed
    // setTimeout(()=>$(window).scrollTop(0),500);

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
    $fixedElement.find('button,a:not(.mobile-file-upload)').each(function(idx, elem){
      if ($(elem).parents('.autocomplete').length > 0) {
        return;
      }

      attachTouchStart(this, function(evt){
        done = true;
        $(document.activeElement).blur();
        evt.preventDefault();
        $(this).click();
      });
    });
    $fixedElement.find('input[type=text],textarea').each(function(){
      attachTouchStart(this, positioningHack);
    });
  }, 100);

  fixedElement.addEventListener('DOMNodeInserted', checkForInputs);
}

export default positioningWorkaround;
