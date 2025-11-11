/*
 *  /MathJax/extensions/fast-preview.js
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

(function(b,g,f){var c=b.config.menuSettings;var e=MathJax.OutputJax;var a=f.isMSIE&&(document.documentMode||0)<8;var d=MathJax.Extension["fast-preview"]={version:"2.7.5",enabled:true,config:b.CombineConfig("fast-preview",{Chunks:{EqnChunk:10000,EqnChunkFactor:1,EqnChunkDelay:0},color:"inherit!important",updateTime:30,updateDelay:6,messageStyle:"none",disabled:f.isMSIE&&!f.versionAtLeast("8.0")}),Config:function(){if(b.config["CHTML-preview"]){MathJax.Hub.Config({"fast-preview":b.config["CHTML-preview"]})}var m,j,k,h,l;var i=this.config;if(!i.disabled&&c.FastPreview==null){b.Config({menuSettings:{FastPreview:true}})}if(c.FastPreview){MathJax.Ajax.Styles({".MathJax_Preview .MJXf-math":{color:i.color}});b.Config({"HTML-CSS":i.Chunks,CommonHTML:i.Chunks,SVG:i.Chunks})}b.Register.MessageHook("Begin Math Output",function(){if(!h&&d.Active()){m=b.processUpdateTime;j=b.processUpdateDelay;k=b.config.messageStyle;b.processUpdateTime=i.updateTime;b.processUpdateDelay=i.updateDelay;b.Config({messageStyle:i.messageStyle});MathJax.Message.Clear(0,0);l=true}});b.Register.MessageHook("End Math Output",function(){if(!h&&l){b.processUpdateTime=m;b.processUpdateDelay=j;b.Config({messageStyle:k});h=true}})},Disable:function(){this.enabled=false},Enable:function(){this.enabled=true},Active:function(){return c.FastPreview&&this.enabled&&!(e[c.renderer]||{}).noFastPreview},Preview:function(h){if(!this.Active()||!h.script.parentNode){return}var i=h.script.MathJax.preview||h.script.previousSibling;if(!i||i.className!==MathJax.Hub.config.preRemoveClass){i=g.Element("span",{className:MathJax.Hub.config.preRemoveClass});h.script.parentNode.insertBefore(i,h.script);h.script.MathJax.preview=i}i.innerHTML="";i.style.color=(a?"black":"inherit");return this.postFilter(i,h)},postFilter:function(j,i){if(!i.math.root.toPreviewHTML){var h=MathJax.Callback.Queue();h.Push(["Require",MathJax.Ajax,"[MathJax]/jax/output/PreviewHTML/config.js"],["Require",MathJax.Ajax,"[MathJax]/jax/output/PreviewHTML/jax.js"]);b.RestartAfter(h.Push({}))}i.math.root.toPreviewHTML(j)},Register:function(h){b.Register.StartupHook(h+" Jax Require",function(){var i=MathJax.InputJax[h];i.postfilterHooks.Add(["Preview",MathJax.Extension["fast-preview"]],50)})}};d.Register("TeX");d.Register("MathML");d.Register("AsciiMath");b.Register.StartupHook("End Config",["Config",d]);b.Startup.signal.Post("fast-preview Ready")})(MathJax.Hub,MathJax.HTML,MathJax.Hub.Browser);MathJax.Ajax.loadComplete("[MathJax]/extensions/fast-preview.js");
