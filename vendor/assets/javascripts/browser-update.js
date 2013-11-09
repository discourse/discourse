//browser-update.org notification script, <browser-update.org>
//Copyright (c) 2007-2009, MIT Style License <browser-update.org/LICENSE.txt>

(function() {

var $buo = function() {

  // sam: my main concern here is mobile, but its an outlier, for now we support ie9, set conditionally and stuff with pushState
  if (window.ie === "new" || (window.history && window.history.pushState)) {
      return;
  }

  // retrieve localized browser upgrade text
  var t = I18n.t('js.browser_update');

  // create the notification div HTML
  var div = document.createElement("div");
  div.className = "buorg";
  div.innerHTML = "<div>" + t + "</div>";

  // create the notification div stylesheet
  var sheet = document.createElement("style");
  var style = ".buorg {position:absolute; z-index:111111; width:100%; top:0px; left:0px; background:#FDF2AB; text-align:left; font-family: sans-serif; color:#000; font-size: 14px;} .buorg div {padding: 8px;} .buorg a, .buorg a:visited {color:#E25600; text-decoration: underline;}";

  // insert the div and stylesheet into the DOM
  document.body.insertBefore(div, document.body.firstChild);
  document.getElementsByTagName("head")[0].appendChild(sheet);
  try {
    sheet.innerText = style;
    sheet.innerHTML = style;
  }
  catch(e) {
    try {
      sheet.styleSheet.cssText = style;
    }
    catch(ex) {
      return;
    }
  }

  // shift the body down to make room for our notification div
  document.body.style.marginTop = (div.clientHeight) + "px";

};

$(function() {
  $bu=$buo();
});

})(this);