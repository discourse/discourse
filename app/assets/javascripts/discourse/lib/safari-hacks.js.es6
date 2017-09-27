export function isAppleDevice() {
  // IE has no DOMNodeInserted so can not get this hack despite saying it is like iPhone
  // This will apply hack on all iDevices
  return navigator.userAgent.match(/(iPad|iPhone|iPod)/g) &&
         navigator.userAgent.match(/Safari/g) &&
         !navigator.userAgent.match(/Trident/g);
}

// we can't tell what the actual visible window height is
// because we cannot account for the height of the mobile keyboard
// and any other mobile autocomplete UI that may appear
// so let's be conservative here rather than trying to max out every
// available pixel of height for the editor
function calcHeight() {

  // estimate 270 px for keyboard
  let withoutKeyboard = window.innerHeight - 270;
  const min = 270;

  // iPhone 6/7/8
  if (window.innerHeight === 553) {
    withoutKeyboard = 308;
  }

  // iPhone 6/7/8 plus
  if (window.innerHeight === 622) {
    withoutKeyboard = 360;
  }

  // iPad landscape, so we have a bigger keyboard
  if (window.innerWidth > window.innerHeight && window.innerHeight > 690) {
    withoutKeyboard -= 128;
  }

  // iPad portrait also has a bigger keyboard
  if (window.innerWidth < window.innerHeight && window.innerHeight > 950) {
    withoutKeyboard -= 45;
  }

  return Math.max(withoutKeyboard, min);
}

let workaroundActive = false;
let composingTopic = false;

export function isWorkaroundActive() {
  return workaroundActive;
}

// per http://stackoverflow.com/questions/29001977/safari-in-ios8-is-scrolling-screen-when-fixed-elements-get-focus/29064810
function positioningWorkaround($fixedElement) {
  if (!isAppleDevice()) {
    return;
  }

  const fixedElement = $fixedElement[0];
  const oldHeight = fixedElement.style.height;

  var done = false;
  var originalScrollTop = 0;

  positioningWorkaround.blur = function(evt) {
    if (workaroundActive) {
      done = true;

      $('#main-outlet').show();
      $('header').show();

      fixedElement.style.position = '';
      fixedElement.style.top = '';
      fixedElement.style.height = oldHeight;

      setTimeout(()=>{
        $(fixedElement).removeClass('no-transition');
      },500);

      $(window).scrollTop(originalScrollTop);

      if (evt) {
        evt.target.removeEventListener('blur', blurred);
      }
      workaroundActive = false;
    }
  };

  var blurredNow = function(evt) {
    if (!done && _.include($(document.activeElement).parents(), fixedElement)) {
      // something in focus so skip
      return;
    }

    positioningWorkaround.blur(evt);

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

    $('#main-outlet').hide();
    $('header').hide();

    $(window).scrollTop(0);

    let i = 20;
    let interval = setInterval(()=>{
      $(window).scrollTop(0);
      if (i--===0) {
        clearInterval(interval);
      }
    }, 10);

    fixedElement.style.top = '0px';

    composingTopic = $('#reply-control .category-select-box').length > 0;

    const height = calcHeight(composingTopic);
    fixedElement.style.height = height + "px";

    $(fixedElement).addClass('no-transition');

    evt.preventDefault();
    self.focus();
    workaroundActive = true;
  };

  function attachTouchStart(elem, fn) {
    if (!$(elem).data('listening')) {
        elem.addEventListener('touchstart', fn);
        $(elem).data('listening', true);
    }
  }

  const checkForInputs = _.debounce(function(){
    $fixedElement.find('button:not(.hide-preview),a:not(.mobile-file-upload):not(.toggle-toolbar)').each(function(idx, elem){
      if ($(elem).parents('.emoji-picker').length > 0) {
        return;
      }

      if ($(elem).parents('.autocomplete').length > 0) {
        return;
      }

      if ($(elem).parents('.d-editor-button-bar').length > 0) {
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
