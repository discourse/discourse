/*
 *  /MathJax/jax/output/CommonHTML/autoload/mglyph.js
 *
 *  Copyright (c) 2009-2018 The MathJax Consortium
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

MathJax.Hub.Register.StartupHook("CommonHTML Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml,b=MathJax.OutputJax.CommonHTML,d=MathJax.Localization;a.mglyph.Augment({toCommonHTML:function(f,r){var o=this.getValues("src","width","height","valign","alt");f=this.CHTMLcreateNode(f);this.CHTMLhandleStyle(f);this.CHTMLhandleScale(f);if(o.src===""){var k=this.Get("index");this.CHTMLgetVariant();if(k&&this.CHTMLvariant.style){this.CHTMLhandleText(f,String.fromCharCode(k),this.CHTMLvariant)}}else{var p=this.CHTML;if(!p.img){p.img=a.mglyph.GLYPH[o.src]}if(!p.img){p.img=a.mglyph.GLYPH[o.src]={img:new Image(),status:"pending"};p.img.img.onload=MathJax.Callback(["CHTMLimgLoaded",this]);p.img.img.onerror=MathJax.Callback(["CHTMLimgError",this]);p.img.img.src=o.src;MathJax.Hub.RestartAfter(p.img.img.onload)}if(p.img.status!=="OK"){var g=a.Error(d._(["MathML","BadMglyph"],"Bad mglyph: %1",o.src));g.data[0].data[0].mathsize="75%";this.Append(g);g.toCommonHTML(f);this.data.pop();p.combine(g.CHTML,0,0,1)}else{var i=b.addElement(f,"img",{isMathJax:true,src:o.src,alt:o.alt,title:o.alt});var m=o.width,j=o.height;var e=p.img.img.width/b.em,n=p.img.img.height/b.em;var q=e,l=n;if(m!==""){e=this.CHTMLlength2em(m,q);n=(q?e/q*l:0)}if(j!==""){n=this.CHTMLlength2em(j,l);if(m===""){e=(l?n/l*q:0)}}i.style.width=b.Em(e);p.w=p.r=e;i.style.height=b.Em(n);p.h=p.t=n;if(o.valign){p.d=p.b=-this.CHTMLlength2em(o.valign,l);i.style.verticalAlign=b.Em(-p.d);p.h-=p.d;p.t=p.h}}}this.CHTMLhandleSpace(f);this.CHTMLhandleBBox(f);this.CHTMLhandleColor(f);return f},CHTMLimgLoaded:function(f,e){if(typeof(f)==="string"){e=f}this.CHTML.img.status=(e||"OK")},CHTMLimgError:function(){this.CHTML.img.img.onload("error")}},{GLYPH:{}});MathJax.Hub.Startup.signal.Post("CommonHTML mglyph Ready");MathJax.Ajax.loadComplete(b.autoloadDir+"/mglyph.js")});
