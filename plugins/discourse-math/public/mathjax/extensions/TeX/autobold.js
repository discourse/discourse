/*
 *  /MathJax/extensions/TeX/autobold.js
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

MathJax.Extension["TeX/autobold"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var a=MathJax.InputJax.TeX;a.prefilterHooks.Add(function(d){var c=d.script.parentNode.insertBefore(document.createElement("span"),d.script);c.visibility="hidden";c.style.fontFamily="Times, serif";c.appendChild(document.createTextNode("ABCXYZabcxyz"));var b=c.offsetWidth;c.style.fontWeight="bold";if(b&&c.offsetWidth===b){d.math="\\boldsymbol{"+d.math+"}"}c.parentNode.removeChild(c)});MathJax.Hub.Startup.signal.Post("TeX autobold Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/autobold.js");
