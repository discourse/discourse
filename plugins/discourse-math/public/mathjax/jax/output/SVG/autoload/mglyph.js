/*
 *  /MathJax/jax/output/SVG/autoload/mglyph.js
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

MathJax.Hub.Register.StartupHook("SVG Jax Ready",function(){var d="2.7.5";var a=MathJax.ElementJax.mml,f=MathJax.OutputJax.SVG,b=f.BBOX,e=MathJax.Localization;var c="http://www.w3.org/1999/xlink";b.MGLYPH=b.Subclass({type:"image",removeable:false,Init:function(j,o,k,l,r,g){if(g==null){g={}}var i=j.width*1000/f.em,p=j.height*1000/f.em;var q=i,n=p,m=0;if(o!==""){i=f.length2em(o,r,q);p=(q?i/q*n:0)}if(k!==""){p=f.length2em(k,r,n);if(o===""){i=(n?p/n*q:0)}}if(l!==""&&l.match(/\d/)){m=f.length2em(l,r);g.y=-m}g.height=Math.floor(p);g.width=Math.floor(i);g.transform="translate(0,"+p+") matrix(1 0 0 -1 0 0)";g.preserveAspectRatio="none";this.SUPER(arguments).Init.call(this,g);this.element.setAttributeNS(c,"href",j.SRC);this.w=this.r=i;this.h=this.H=p+m;this.d=this.D=-m;this.l=0}});a.mglyph.Augment({toSVG:function(k,n){this.SVGgetStyles();var j=this.SVG(),i,l;this.SVGhandleSpace(j);var h=this.getValues("src","width","height","valign","alt");if(h.src===""){h=this.getValues("index","fontfamily");if(h.index){if(!n){n=this.SVGgetScale()}var m={};if(h.fontfamily){m["font-family"]=h.fontfamily}j.Add(b.TEXT(n,String.fromCharCode(h.index),m))}}else{if(!this.img){this.img=a.mglyph.GLYPH[h.src]}if(!this.img){this.img=a.mglyph.GLYPH[h.src]={img:new Image(),status:"pending"};i=this.img.img;i.onload=MathJax.Callback(["SVGimgLoaded",this]);i.onerror=MathJax.Callback(["SVGimgError",this]);i.src=i.SRC=h.src;MathJax.Hub.RestartAfter(i.onload)}if(this.img.status!=="OK"){l=a.Error(e._(["MathML","BadMglyph"],"Bad mglyph: %1",h.src),{mathsize:"75%"});this.Append(l);j=l.toSVG();this.data.pop()}else{var g=this.SVGgetMu(j);j.Add(b.MGLYPH(this.img.img,h.width,h.height,h.valign,g,{alt:h.alt,title:h.alt}))}}j.Clean();this.SVGhandleColor(j);this.SVGsaveData(j);return j},SVGimgLoaded:function(h,g){if(typeof(h)==="string"){g=h}this.img.status=(g||"OK")},SVGimgError:function(){this.img.img.onload("error")}},{GLYPH:{}});MathJax.Hub.Startup.signal.Post("SVG mglyph Ready");MathJax.Ajax.loadComplete(f.autoloadDir+"/mglyph.js")});
