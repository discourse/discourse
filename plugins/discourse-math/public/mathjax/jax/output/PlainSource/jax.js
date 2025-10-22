/*
 *  /MathJax/jax/output/PlainSource/jax.js
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

(function(a,b,f,c){var e,g,d;c.Augment({settings:b.config.menuSettings,Config:function(){if(!this.require){this.require=[]}this.SUPER(arguments).Config.call(this);this.require.push(MathJax.OutputJax.extensionDir+"/MathEvents.js")},Startup:function(){e=MathJax.Extension.MathEvents.Event;g=MathJax.Extension.MathEvents.Touch;d=MathJax.Extension.MathEvents.Hover;this.ContextMenu=e.ContextMenu;this.Mousedown=e.AltContextMenu;this.Mouseover=d.Mouseover;this.Mouseout=d.Mouseout;this.Mousemove=d.Mousemove;return a.Styles(this.config.styles)},preTranslate:function(k){var o=k.jax[this.id],p,l=o.length,q,n,r,j,h;for(p=0;p<l;p++){q=o[p];if(!q.parentNode){continue}n=q.previousSibling;if(n&&String(n.className).match(/^MathJax(_PlainSource)?(_Display)?( MathJax_Process(ing|ed))?$/)){n.parentNode.removeChild(n)}h=q.MathJax.elementJax;if(!h){continue}h.PlainSource={display:(h.root.Get("display")==="block")};r=j=f.Element("span",{className:"MathJax_PlainSource",id:h.inputID+"-Frame",isMathJax:true,jaxID:this.id,oncontextmenu:e.Menu,onmousedown:e.Mousedown,onmouseover:e.Mouseover,onmouseout:e.Mouseout,onmousemove:e.Mousemove,onclick:e.Click,ondblclick:e.DblClick,onkeydown:e.Keydown,tabIndex:b.getTabOrder(h)},[["span"]]);if(b.Browser.noContextMenu){r.ontouchstart=g.start;r.ontouchend=g.end}if(h.PlainSource.display){j=f.Element("div",{className:"MathJax_PlainSource_Display"});j.appendChild(r)}q.parentNode.insertBefore(j,q)}},Translate:function(j,n){if(!j.parentNode){return}var i=j.MathJax.elementJax,l=i.root,k=document.getElementById(i.inputID+"-Frame");this.initPlainSource(l,k);var m=i.originalText;if(i.inputJax==="MathML"){if((i.root.data[0].data.length>0)&&(i.root.data[0].data[0].type==="semantics")){var o=i.root.data[0].data[0].data;for(var h=0;h<o.length;h++){if(o[h].attr.encoding==="application/x-tex"){m=i.root.data[0].data[0].data[h].data[0].data[0];break}if(o[h].attr.encoding==="text/x-asciimath"){m=i.root.data[0].data[0].data[h].data[0].data[0]}}}}i.PlainSource.source=m;f.addText(k.firstChild,m)},postTranslate:function(h){},getJaxFromMath:function(h){if(h.parentNode.className.match(/MathJax_PlainSource_Display/)){h=h.parentNode}do{h=h.nextSibling}while(h&&h.nodeName.toLowerCase()!=="script");return b.getJaxFor(h)},Zoom:function(i,q,p,h,n){var k=Math.round(q.parentNode.offsetWidth/2);q.style.whiteSpace="pre";f.addText(q,i.PlainSource.source);var l=p.offsetWidth,r=p.offsetHeight,o=q.offsetWidth,m=q.offsetHeight;var j=-Math.round((m+r)/2)-(i.PlainSource.display?0:k);return{mW:l,mH:r,zW:o,zH:m,Y:j}},initPlainSource:function(i,h){},Remove:function(h){var i=document.getElementById(h.inputID+"-Frame");if(i){if(h.PlainSource.display){i=i.parentNode}i.parentNode.removeChild(i)}delete h.PlainSource}});MathJax.Hub.Register.StartupHook("mml Jax Ready",function(){MathJax.Hub.Register.StartupHook("onLoad",function(){setTimeout(MathJax.Callback(["loadComplete",c,"jax.js"]),0)})});MathJax.Hub.Register.StartupHook("End Cookie",function(){if(b.config.menuSettings.zoom!=="None"){a.Require("[MathJax]/extensions/MathZoom.js")}})})(MathJax.Ajax,MathJax.Hub,MathJax.HTML,MathJax.OutputJax.PlainSource);
