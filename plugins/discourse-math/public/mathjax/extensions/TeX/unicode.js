/*
 *  /MathJax/extensions/TeX/unicode.js
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

MathJax.Extension["TeX/unicode"]={version:"2.7.5",unicode:{},config:MathJax.Hub.CombineConfig("TeX.unicode",{fonts:"STIXGeneral,'Arial Unicode MS'"})};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var c=MathJax.InputJax.TeX;var a=MathJax.ElementJax.mml;var b=MathJax.Extension["TeX/unicode"].unicode;c.Definitions.Add({macros:{unicode:"Unicode"}},null,true);c.Parse.Augment({Unicode:function(e){var i=this.GetBrackets(e),d;if(i){if(i.replace(/ /g,"").match(/^(\d+(\.\d*)?|\.\d+),(\d+(\.\d*)?|\.\d+)$/)){i=i.replace(/ /g,"").split(/,/);d=this.GetBrackets(e)}else{d=i;i=null}}var j=this.trimSpaces(this.GetArgument(e)).replace(/^0x/,"x");if(!j.match(/^(x[0-9A-Fa-f]+|[0-9]+)$/)){c.Error(["BadUnicode","Argument to \\unicode must be a number"])}var h=parseInt(j.match(/^x/)?"0"+j:j);if(!b[h]){b[h]=[800,200,d,h]}else{if(!d){d=b[h][2]}}if(i){b[h][0]=Math.floor(i[0]*1000);b[h][1]=Math.floor(i[1]*1000)}var f=this.stack.env.font,g={};if(d){b[h][2]=g.fontfamily=d.replace(/"/g,"'");if(f){if(f.match(/bold/)){g.fontweight="bold"}if(f.match(/italic|-mathit/)){g.fontstyle="italic"}}}else{if(f){g.mathvariant=f}}g.unicode=[].concat(b[h]);this.Push(a.mtext(a.entity("#"+j)).With(g))}});MathJax.Hub.Startup.signal.Post("TeX unicode Ready")});MathJax.Hub.Register.StartupHook("HTML-CSS Jax Ready",function(){var a=MathJax.ElementJax.mml;var c=MathJax.Extension["TeX/unicode"].config.fonts;var b=a.mbase.prototype.HTMLgetVariant;a.mbase.Augment({HTMLgetVariant:function(){var d=b.apply(this,arguments);if(d.unicode){delete d.unicode;delete d.FONTS}if(!this.unicode){return d}d.unicode=true;if(!d.defaultFont){d=MathJax.Hub.Insert({},d);d.defaultFont={family:c}}var e=this.unicode[2];if(e){e+=","+c}else{e=c}d.defaultFont[this.unicode[3]]=[this.unicode[0],this.unicode[1],500,0,500,{isUnknown:true,isUnicode:true,font:e}];return d}})});MathJax.Hub.Register.StartupHook("SVG Jax Ready",function(){var a=MathJax.ElementJax.mml;var c=MathJax.Extension["TeX/unicode"].config.fonts;var b=a.mbase.prototype.SVGgetVariant;a.mbase.Augment({SVGgetVariant:function(){var d=b.call(this);if(d.unicode){delete d.unicode;delete d.FONTS}if(!this.unicode){return d}d.unicode=true;if(!d.forceFamily){d=MathJax.Hub.Insert({},d)}d.defaultFamily=c;d.noRemap=true;d.h=this.unicode[0];d.d=this.unicode[1];return d}})});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/unicode.js");
