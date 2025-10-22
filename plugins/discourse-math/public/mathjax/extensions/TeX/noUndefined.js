/*
 *  /MathJax/extensions/TeX/noUndefined.js
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

MathJax.Extension["TeX/noUndefined"]={version:"2.7.5",config:MathJax.Hub.CombineConfig("TeX.noUndefined",{disabled:false,attributes:{mathcolor:"red"}})};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var b=MathJax.Extension["TeX/noUndefined"].config;var a=MathJax.ElementJax.mml;var c=MathJax.InputJax.TeX.Parse.prototype.csUndefined;MathJax.InputJax.TeX.Parse.Augment({csUndefined:function(d){if(b.disabled){return c.apply(this,arguments)}MathJax.Hub.signal.Post(["TeX Jax - undefined control sequence",d]);this.Push(a.mtext(d).With(b.attributes))}});MathJax.Hub.Startup.signal.Post("TeX noUndefined Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/noUndefined.js");
