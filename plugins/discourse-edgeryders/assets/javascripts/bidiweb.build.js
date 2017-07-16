// bidi_helpers.js
//
// From http://closure-library.googlecode.com/svn-history/r27/trunk/closure/goog/docs/closure_goog_i18n_bidi.js.source.html
// with modifications
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License

// bidiweb.js
// Hasen el Judy
// This file is licensed under the WTFPL.

(function(e){typeof define=="function"&&define.amd?define("bidi_helpers",[],e):window.bidi_helpers=e()})(function(){var e={};return e.Dir={RTL:-1,UNKNOWN:0,LTR:1},e.Format={LRE:"‪",RLE:"‫",PDF:"‬",LRM:"‎",RLM:"‏"},e.ltrChars_="A-Za-zÀ-ÖØ-öø-ʸ̀-֐ࠀ-῿Ⰰ-﬜︀-﹯﻽-￿",e.rtlChars_="֑-߿יִ-﷿ﹰ-ﻼ",e.ltrDirCheckRe_=new RegExp("^[^"+e.rtlChars_+"]*["+e.ltrChars_+"]"),e.ltrCharReg_=new RegExp("["+e.ltrChars_+"]"),e.hasAnyLtr=function(t){return e.ltrCharReg_.test(t)},e.rtlDirCheckRe_=new RegExp("^[^"+e.ltrChars_+"]*["+e.rtlChars_+"]"),e.rtlRe=e.rtlDirCheckRe_,e.isRtlText=function(t){return e.rtlDirCheckRe_.test(t)},e.isLtrText=function(t){return e.ltrDirCheckRe_.test(t)},e.isRequiredLtrRe_=/^http:\/\/.*/,e.hasNumeralsRe_=/\d/,e.estimateDirection=function(t,n){var r=0,i=0,s=!1,o=t.split(/\s+/);for(var u=0;u<o.length;u++){var a=o[u];e.isRtlText(a)?(r++,i++):e.isRequiredLtrRe_.test(a)?s=!0:e.hasAnyLtr(a)?i++:e.hasNumeralsRe_.test(a)&&(s=!0)}return i==0?s?e.Dir.LTR:e.Dir.UNKNOWN:r/i>n?e.Dir.RTL:e.Dir.LTR},e}),function(e){typeof define=="function"&&define.amd?define("bidiweb",["bidi_helpers"],e):window.bidiweb=e(bidi_helpers)}(function(e){var t={},n={makeRtl:function(e){},makeLtr:function(e){}},r=function(e){return{makeRtl:function(t){t.classList.add(e.rtl)},makeLtr:function(t){t.classList.add(e.ltr)}}},i=function(e){return{makeRtl:function(t){t.style.direction="rtl",e&&(t.style.textAlign="right")},makeLtr:function(t){t.style.direction="ltr",e&&(t.style.textAlign="left")}}};t.processors={css:r,style:i};var s=function(e){var t=[e];return t.item=function(e){return t[e]},t};return t.process=function(e,n){var r;return e instanceof NodeList?r=e:e instanceof Node?r=s(e):r=document.querySelectorAll(e),t.process_elements(r,n),r},t.process_elements=function(t,n){for(var r=0;r<t.length;r++){var i=t.item(r),s=i.textContent||i.value||i.placeholder||"",o=e.estimateDirection(s,.4);o==e.Dir.RTL?n.makeRtl(i):o==e.Dir.LTR&&n.makeLtr(i)}},t.process_css=function(e,n){var r=t.processors.css(n);return t.process(e,r)},t.process_style=function(e,n){var r=t.processors.style(n);return t.process(e,r)},t.style=function(e){return t.process_style(e,!0)},t.css=function(e){return t.process_css(e,{rtl:"rtl",ltr:"ltr"})},t.htmlToElement=function(e){var t=document.createElement("div");return t.innerHTML=e,t},t.html_css=function(e){var n=t.htmlToElement(e),r=n.querySelectorAll("*");return t.css(r),n.innerHTML},t.html_style=function(e){var n=t.htmlToElement(e),r=n.querySelectorAll("*");return t.style(r),n.innerHTML},t});
