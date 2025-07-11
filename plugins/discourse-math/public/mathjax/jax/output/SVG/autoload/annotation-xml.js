/*
 *  /MathJax/jax/output/SVG/autoload/annotation-xml.js
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

MathJax.Hub.Register.StartupHook("SVG Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml,d=MathJax.OutputJax.SVG;var b=d.BBOX;b.FOREIGN=b.Subclass({type:"foreignObject",removeable:false});a["annotation-xml"].Augment({toSVG:function(){var f=this.SVG();this.SVGhandleSpace(f);var h=this.Get("encoding");for(var g=0,e=this.data.length;g<e;g++){f.Add(this.data[g].toSVG(h),f.w,0)}f.Clean();this.SVGhandleColor(f);this.SVGsaveData(f);return f}});a.xml.Augment({toSVG:function(e){var p=d.textSVG.parentNode;d.mathDiv.style.width="auto";p.insertBefore(this.div,d.textSVG);var q=this.div.offsetWidth,k=this.div.offsetHeight;var o=MathJax.HTML.addElement(this.div,"span",{style:{display:"inline-block",overflow:"hidden",height:k+"px",width:"1px",marginRight:"-1px"}});var n=this.div.offsetHeight-k;k-=n;this.div.removeChild(o);p.removeChild(this.div);d.mathDiv.style.width="";var g=1000/d.em;var l=b.FOREIGN({y:(-k)+"px",width:q+"px",height:(k+n)+"px",transform:"scale("+g+") matrix(1 0 0 -1 0 0)"});for(var j=0,f=this.data.length;j<f;j++){l.element.appendChild(this.data[j].cloneNode(true))}l.w=q*g;l.h=k*g;l.d=n*g;l.r=l.w;l.l=0;l.Clean();this.SVGsaveData(l);return l}});MathJax.Hub.Startup.signal.Post("SVG annotation-xml Ready");MathJax.Ajax.loadComplete(d.autoloadDir+"/annotation-xml.js")});
