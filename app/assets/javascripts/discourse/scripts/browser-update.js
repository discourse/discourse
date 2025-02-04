//browser-update.org notification script, <browser-update.org>
//Copyright (c) 2007-2009, MIT Style License <browser-update.org/LICENSE.txt>

/* eslint-disable no-var */

(function () {
  var $buo = function () {
    // Sometimes we have to resort to parsing the user agent string. :(
    if (navigator && navigator.userAgent) {
      var ua = navigator.userAgent;

      // we don't ask Googlebot to update their browser
      if (
        ua.indexOf("Googlebot") >= 0 ||
        ua.indexOf("Mediapartners") >= 0 ||
        ua.indexOf("AdsBot") >= 0
      ) {
        return;
      }
    }

    if (!window.unsupportedBrowser) {
      return;
    }

    document.getElementsByTagName("body")[0].className += " crawler";
    var noscriptElements = document.getElementsByTagName("noscript");
    // find the element with the "data-path" attribute set
    for (var i = noscriptElements.length - 1; i >= 0; i--) {
      var element = noscriptElements[i];

      // noscriptElements[i].innerHTML contains encoded HTML, so we need to access
      // the childNodes instead. Browsers seem to split very long content into multiple
      // text childNodes.
      var result = "";
      for (var j = 0; j < element.childNodes.length; j++) {
        result += element.childNodes[j].nodeValue;
      }

      if (element.getAttribute("data-path")) {
        document.getElementById("main").outerHTML = result;
      } else {
        element.outerHTML = result;
      }
    }

    // retrieve localized browser upgrade text
    var t = window.I18n && I18n.t("browser_update"); // eslint-disable-line no-undef
    if (!t || t.indexOf(".browser_update]") !== -1) {
      // very old browsers might fail to load even translations
      t =
        'Unfortunately, <a href="https://www.discourse.org/faq/#browser">your browser is unsupported</a>. Please <a href="https://browsehappy.com">switch to a supported browser</a> to view rich content, log in and reply.';
    }

    // create the notification div HTML
    var div = document.createElement("div");
    div.className = "buorg";
    div.innerHTML = "<div>" + t + "</div>";

    // create the notification div stylesheet
    var sheet = document.createElement("style");
    var style =
      ".buorg {position:absolute; z-index:111111; width:100%; top:0px; left:0px; background:#FDF2AB; text-align:left; font-family: sans-serif; color:#000; font-size: 14px;} .buorg div {padding: 8px;} .buorg a, .buorg a:visited {color:#E25600; text-decoration: underline;} @media print { .buorg { display: none !important; } }";

    // insert the div and stylesheet into the DOM
    document.body.appendChild(div); // put it last in the DOM so Googlebot doesn't include it in search excerpts
    document.getElementsByTagName("head")[0].appendChild(sheet);
    try {
      sheet.innerText = style;
      sheet.innerHTML = style;
      // eslint-disable-next-line no-unused-vars -- old browsers require binding this variable, even if unused
    } catch (e) {
      try {
        sheet.styleSheet.cssText = style;
        // eslint-disable-next-line no-unused-vars -- old browser require binding this variable, even if unused
      } catch (ex) {
        return;
      }
    }

    // shift the body down to make room for our notification div
    document.body.style.marginTop = div.clientHeight + "px";
  };

  $bu = $buo(); // eslint-disable-line no-undef
})(this);
