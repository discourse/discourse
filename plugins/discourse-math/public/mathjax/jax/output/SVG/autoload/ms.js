/*
 *  /MathJax/jax/output/SVG/autoload/ms.js
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

MathJax.Hub.Register.StartupHook("SVG Jax Ready",function(){var b="2.7.5";var a=MathJax.ElementJax.mml,c=MathJax.OutputJax.SVG;a.ms.Augment({toSVG:function(){this.SVGgetStyles();var e=this.SVG();this.SVGhandleSpace(e);var d=this.getValues("lquote","rquote","mathvariant");if(!this.hasValue("lquote")||d.lquote==='"'){d.lquote="\u201C"}if(!this.hasValue("rquote")||d.rquote==='"'){d.rquote="\u201D"}if(d.lquote==="\u201C"&&d.mathvariant==="monospace"){d.lquote='"'}if(d.rquote==="\u201D"&&d.mathvariant==="monospace"){d.rquote='"'}var f=this.SVGgetVariant(),h=this.SVGgetScale();var g=d.lquote+this.data.join("")+d.rquote;e.Add(this.SVGhandleVariant(f,h,g));e.Clean();this.SVGhandleColor(e);this.SVGsaveData(e);return e}});MathJax.Hub.Startup.signal.Post("SVG ms Ready");MathJax.Ajax.loadComplete(c.autoloadDir+"/ms.js")});
