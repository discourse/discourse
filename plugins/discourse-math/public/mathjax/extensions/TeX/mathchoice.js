/*
 *  /MathJax/extensions/TeX/mathchoice.js
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

MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml;var d=MathJax.InputJax.TeX;var b=d.Definitions;b.Add({macros:{mathchoice:"MathChoice"}},null,true);d.Parse.Augment({MathChoice:function(f){var i=this.ParseArg(f),e=this.ParseArg(f),g=this.ParseArg(f),h=this.ParseArg(f);this.Push(a.TeXmathchoice(i,e,g,h))}});a.TeXmathchoice=a.mbase.Subclass({type:"TeXmathchoice",notParent:true,choice:function(){if(this.selection!=null){return this.selection}if(this.choosing){return 2}this.choosing=true;var f=0,e=this.getValues("displaystyle","scriptlevel");if(e.scriptlevel>0){f=Math.min(3,e.scriptlevel+1)}else{f=(e.displaystyle?0:1)}var g=this.inherit;while(g&&g.type!=="math"){g=g.inherit}if(g){this.selection=f}this.choosing=false;return f},selected:function(){return this.data[this.choice()]},setTeXclass:function(e){return this.selected().setTeXclass(e)},isSpacelike:function(){return this.selected().isSpacelike()},isEmbellished:function(){return this.selected().isEmbellished()},Core:function(){return this.selected()},CoreMO:function(){return this.selected().CoreMO()},toHTML:function(e){e=this.HTMLcreateSpan(e);e.bbox=this.Core().toHTML(e).bbox;if(e.firstChild&&e.firstChild.style.marginLeft){e.style.marginLeft=e.firstChild.style.marginLeft;e.firstChild.style.marginLeft=""}return e},toSVG:function(){var e=this.Core().toSVG();this.SVGsaveData(e);return e},toCommonHTML:function(e){e=this.CHTMLcreateNode(e);this.CHTMLhandleStyle(e);this.CHTMLhandleColor(e);this.CHTMLaddChild(e,this.choice(),{});return e},toPreviewHTML:function(e){e=this.PHTMLcreateSpan(e);this.PHTMLhandleStyle(e);this.PHTMLhandleColor(e);this.PHTMLaddChild(e,this.choice(),{});return e}});MathJax.Hub.Startup.signal.Post("TeX mathchoice Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/mathchoice.js");
