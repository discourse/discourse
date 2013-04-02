//browser-update.org notification script, <browser-update.org>
//Copyright (c) 2007-2009, MIT Style License <browser-update.org/LICENSE.txt>

(function() {

var $buo = function() {

  this.op = {};

  // sam: my main concern here is mobile, but its an outlier, for now we support ie9, set conditionally and stuff with pushState
  if (window.ie === "new" || (window.history && window.history.pushState)) {
      return;
  }

  var t = I18n.t('js.browser_update');

  var div = document.createElement("div");
  this.op.div = div;
  div.id="buorg";
  div.className="buorg";
  div.innerHTML= '<div>' + t + '<div id="buorgclose">&times;</div></div>';

  var sheet = document.createElement("style");

  var style = ".buorg {position:absolute; z-index:111111;" +
  "width:100%; top:0px; left:0px" +
  "border-bottom:1px solid #A29330; " +
  "background:#FDF2AB;" +
  "text-align:left; " +
  "font-family: sans-serif; color:#000; font-size: 14px;}" +
  ".buorg div { padding: 8px; } " +
  ".buorg a, .buorg a:visited  {color:#E25600; text-decoration: underline;}" +
  "#buorgclose { position: absolute; right: .5em; top:.2em; font-weight: bold; font-size:28px; padding:0; color: #A29330; }";

  document.body.insertBefore(div,document.body.firstChild);
  document.getElementsByTagName("head")[0].appendChild(sheet);
  try {
    sheet.innerText=style;
    sheet.innerHTML=style;
  }
  catch(e) {
    try {
      sheet.styleSheet.cssText = style;
    }
    catch(ex) {
      return;
    }
  }
  var me=this;


  this.op.bodymt = document.body.style.marginTop;
  document.body.style.marginTop = (div.clientHeight)+"px";

  document.getElementById("buorgclose").onclick = function(e) {
      var evt = e || window.event;
      if (evt.stopPropagation) evt.stopPropagation();
      else evt.cancelBubble = true;
      me.op.div.style.display="none";
      document.body.style.marginTop = me.op.bodymt;
      return true;
  };

};

$bu=$buo();

})(this);
