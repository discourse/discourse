/*
 *  /MathJax/jax/output/HTML-CSS/autoload/mglyph.js
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

MathJax.Hub.Register.StartupHook("HTML-CSS Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml,b=MathJax.OutputJax["HTML-CSS"],d=MathJax.Localization;a.mglyph.Augment({toHTML:function(k,g){var j=k,l=this.getValues("src","width","height","valign","alt"),f;k=this.HTMLcreateSpan(k);if(l.src===""){var i=this.Get("index");if(i){g=this.HTMLgetVariant();var e=g.defaultFont;if(e){e.noStyleChar=true;e.testString=String.fromCharCode(i)+"ABCabc";if(b.Font.testFont(e)){this.HTMLhandleVariant(k,g,String.fromCharCode(i))}else{if(l.alt===""){l.alt=d._(["MathML","BadMglyphFont"],"Bad font: %1",e.family)}f=a.Error(l.alt,{mathsize:"75%"});this.Append(f);f.toHTML(k);this.data.pop();k.bbox=f.HTMLspanElement().bbox}}}}else{if(!this.img){this.img=a.mglyph.GLYPH[l.src]}if(!this.img){this.img=a.mglyph.GLYPH[l.src]={img:new Image(),status:"pending"};var h=this.img.img;h.onload=MathJax.Callback(["HTMLimgLoaded",this]);h.onerror=MathJax.Callback(["HTMLimgError",this]);h.src=l.src;MathJax.Hub.RestartAfter(h.onload)}if(this.img.status!=="OK"){f=a.Error(d._(["MathML","BadMglyph"],"Bad mglyph: %1",l.src),{mathsize:"75%"});this.Append(f);f.toHTML(k);this.data.pop();k.bbox=f.HTMLspanElement().bbox}else{var m=this.HTMLgetMu(k);h=b.addElement(k,"img",{isMathJax:true,src:l.src,alt:l.alt,title:l.alt});if(l.width){h.style.width=b.Em(b.length2em(l.width,m,this.img.img.width/b.em))}if(l.height){h.style.height=b.Em(b.length2em(l.height,m,this.img.img.height/b.em))}k.bbox.w=k.bbox.rw=h.offsetWidth/b.em;k.bbox.h=h.offsetHeight/b.em;if(l.valign){k.bbox.d=-b.length2em(l.valign,m,this.img.img.height/b.em);h.style.verticalAlign=b.Em(-k.bbox.d);k.bbox.h-=k.bbox.d}}}if(!j.bbox){j.bbox={w:k.bbox.w,h:k.bbox.h,d:k.bbox.d,rw:k.bbox.rw,lw:k.bbox.lw}}else{if(k.bbox){j.bbox.w+=k.bbox.w;if(j.bbox.w>j.bbox.rw){j.bbox.rw=j.bbox.w}if(k.bbox.h>j.bbox.h){j.bbox.h=k.bbox.h}if(k.bbox.d>j.bbox.d){j.bbox.d=k.bbox.d}}}this.HTMLhandleSpace(k);this.HTMLhandleColor(k);return k},HTMLimgLoaded:function(f,e){if(typeof(f)==="string"){e=f}this.img.status=(e||"OK")},HTMLimgError:function(){this.img.img.onload("error")}},{GLYPH:{}});MathJax.Hub.Startup.signal.Post("HTML-CSS mglyph Ready");MathJax.Ajax.loadComplete(b.autoloadDir+"/mglyph.js")});
