/*
 *  /MathJax/extensions/TeX/verb.js
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

MathJax.Extension["TeX/verb"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var a=MathJax.ElementJax.mml;var c=MathJax.InputJax.TeX;var b=c.Definitions;b.Add({macros:{verb:"Verb"}},null,true);c.Parse.Augment({Verb:function(d){var g=this.GetNext();var f=++this.i;if(g==""){c.Error(["MissingArgFor","Missing argument for %1",d])}while(this.i<this.string.length&&this.string.charAt(this.i)!=g){this.i++}if(this.i==this.string.length){c.Error(["NoClosingDelim","Can't find closing delimiter for %1",d])}var e=this.string.slice(f,this.i).replace(/ /g,"\u00A0");this.i++;this.Push(a.mtext(e).With({mathvariant:a.VARIANT.MONOSPACE}))}});MathJax.Hub.Startup.signal.Post("TeX verb Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/verb.js");
