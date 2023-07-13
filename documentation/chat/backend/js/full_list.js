(function() {

var $clicked = $(null);
var searchTimeout = null;
var searchCache = [];
var caseSensitiveMatch = false;
var ignoreKeyCodeMin = 8;
var ignoreKeyCodeMax = 46;
var commandKey = 91;

RegExp.escape = function(text) {
    return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
}

function escapeShortcut() {
  $(document).keydown(function(evt) {
    if (evt.which == 27) {
      window.parent.postMessage('navEscape', '*');
    }
  });
}

function navResizer() {
  $(window).mousemove(function(e) {
    window.parent.postMessage({
      action: 'mousemove', event: {pageX: e.pageX, which: e.which}
    }, '*');
  }).mouseup(function(e) {
    window.parent.postMessage({action: 'mouseup'}, '*');
  });
  window.parent.postMessage("navReady", "*");
}

function clearSearchTimeout() {
  clearTimeout(searchTimeout);
  searchTimeout = null;
}

function enableLinks() {
  // load the target page in the parent window
  $('#full_list li').on('click', function(evt) {
    $('#full_list li').removeClass('clicked');
    $clicked = $(this);
    $clicked.addClass('clicked');
    evt.stopPropagation();

    if (evt.target.tagName === 'A') return true;

    var elem = $clicked.find('> .item .object_link a')[0];
    var e = evt.originalEvent;
    var newEvent = new MouseEvent(evt.originalEvent.type);
    newEvent.initMouseEvent(e.type, e.canBubble, e.cancelable, e.view, e.detail, e.screenX, e.screenY, e.clientX, e.clientY, e.ctrlKey, e.altKey, e.shiftKey, e.metaKey, e.button, e.relatedTarget);
    elem.dispatchEvent(newEvent);
    evt.preventDefault();
    return false;
  });
}

function enableToggles() {
  // show/hide nested classes on toggle click
  $('#full_list a.toggle').on('click', function(evt) {
    evt.stopPropagation();
    evt.preventDefault();
    $(this).parent().parent().toggleClass('collapsed');
    highlight();
  });
}

function populateSearchCache() {
  $('#full_list li .item').each(function() {
    var $node = $(this);
    var $link = $node.find('.object_link a');
    if ($link.length > 0) {
      searchCache.push({
        node: $node,
        link: $link,
        name: $link.text(),
        fullName: $link.attr('title').split(' ')[0]
      });
    }
  });
}

function enableSearch() {
  $('#search input').keyup(function(event) {
    if (ignoredKeyPress(event)) return;
    if (this.value === "") {
      clearSearch();
    } else {
      performSearch(this.value);
    }
  });

  $('#full_list').after("<div id='noresults' style='display:none'></div>");
}

function ignoredKeyPress(event) {
  if (
    (event.keyCode > ignoreKeyCodeMin && event.keyCode < ignoreKeyCodeMax) ||
    (event.keyCode == commandKey)
  ) {
    return true;
  } else {
    return false;
  }
}

function clearSearch() {
  clearSearchTimeout();
  $('#full_list .found').removeClass('found').each(function() {
    var $link = $(this).find('.object_link a');
    $link.text($link.text());
  });
  $('#full_list, #content').removeClass('insearch');
  $clicked.parents().removeClass('collapsed');
  highlight();
}

function performSearch(searchString) {
  clearSearchTimeout();
  $('#full_list, #content').addClass('insearch');
  $('#noresults').text('').hide();
  partialSearch(searchString, 0);
}

function partialSearch(searchString, offset) {
  var lastRowClass = '';
  var i = null;
  for (i = offset; i < Math.min(offset + 50, searchCache.length); i++) {
    var item = searchCache[i];
    var searchName = (searchString.indexOf('::') != -1 ? item.fullName : item.name);
    var matchString = buildMatchString(searchString);
    var matchRegexp = new RegExp(matchString, caseSensitiveMatch ? "" : "i");
    if (searchName.match(matchRegexp) == null) {
      item.node.removeClass('found');
      item.link.text(item.link.text());
    }
    else {
      item.node.addClass('found');
      item.node.removeClass(lastRowClass).addClass(lastRowClass == 'r1' ? 'r2' : 'r1');
      lastRowClass = item.node.hasClass('r1') ? 'r1' : 'r2';
      item.link.html(item.name.replace(matchRegexp, "<strong>$&</strong>"));
    }
  }
  if(i == searchCache.length) {
    searchDone();
  } else {
    searchTimeout = setTimeout(function() {
      partialSearch(searchString, i);
    }, 0);
  }
}

function searchDone() {
  searchTimeout = null;
  highlight();
  if ($('#full_list li:visible').size() === 0) {
    $('#noresults').text('No results were found.').hide().fadeIn();
  } else {
    $('#noresults').text('').hide();
  }
  $('#content').removeClass('insearch');
}

function buildMatchString(searchString, event) {
  caseSensitiveMatch = searchString.match(/[A-Z]/) != null;
  var regexSearchString = RegExp.escape(searchString);
  if (caseSensitiveMatch) {
    regexSearchString += "|" +
      $.map(searchString.split(''), function(e) { return RegExp.escape(e); }).
      join('.+?');
  }
  return regexSearchString;
}

function highlight() {
  $('#full_list li:visible').each(function(n) {
    $(this).removeClass('even odd').addClass(n % 2 == 0 ? 'odd' : 'even');
  });
}

/**
 * Expands the tree to the target element and its immediate
 * children.
 */
function expandTo(path) {
  var $target = $(document.getElementById('object_' + path));
  $target.addClass('clicked');
  $target.removeClass('collapsed');
  $target.parentsUntil('#full_list', 'li').removeClass('collapsed');
  if($target[0]) {
    window.scrollTo(window.scrollX, $target.offset().top - 250);
    highlight();
  }
}

function windowEvents(event) {
  var msg = event.data;
  if (msg.action === "expand") {
    expandTo(msg.path);
  }
  return false;
}

window.addEventListener("message", windowEvents, false);

$(document).ready(function() {
  escapeShortcut();
  navResizer();
  enableLinks();
  enableToggles();
  populateSearchCache();
  enableSearch();
});

})();
