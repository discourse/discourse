/*
 *  /MathJax/extensions/TeX/autoload-all.js
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

MathJax.Extension["TeX/autoload-all"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var h={action:["mathtip","texttip","toggle"],AMSmath:["mathring","nobreakspace","negmedspace","negthickspace","intI","iiiint","idotsint","dddot","ddddot","sideset","boxed","substack","injlim","projlim","varliminf","varlimsup","varinjlim","varprojlim","DeclareMathOperator","operatorname","genfrac","tfrac","dfrac","binom","tbinom","dbinom","cfrac","shoveleft","shoveright","xrightarrow","xleftarrow"],begingroup:["begingroup","endgroup","gdef","global"],cancel:["cancel","bcancel","xcancel","cancelto"],color:["color","textcolor","colorbox","fcolorbox","definecolor"],enclose:["enclose"],extpfeil:["Newextarrow","xlongequal","xmapsto","xtofrom","xtwoheadleftarrow","xtwoheadrightarrow"],mhchem:["ce","cee","cf"]};var c={AMSmath:["subarray","smallmatrix","equation","equation*"],AMScd:["CD"]};var d,g,b,a={macros:{},environment:{}};for(d in h){if(h.hasOwnProperty(d)){if(!MathJax.Extension["TeX/"+d]){var f=h[d];for(g=0,b=f.length;g<b;g++){a.macros[f[g]]=["Extension",d]}}}}for(d in c){if(c.hasOwnProperty(d)){if(!MathJax.Extension["TeX/"+d]){var e=c[d];for(g=0,b=e.length;g<b;g++){a.environment[e[g]]=["ExtensionEnv",null,d]}}}}MathJax.InputJax.TeX.Definitions.Add(a);MathJax.Hub.Startup.signal.Post("TeX autoload-all Ready")});MathJax.Callback.Queue(["Require",MathJax.Ajax,"[MathJax]/extensions/TeX/AMSsymbols.js"],["loadComplete",MathJax.Ajax,"[MathJax]/extensions/TeX/autoload-all.js"]);
