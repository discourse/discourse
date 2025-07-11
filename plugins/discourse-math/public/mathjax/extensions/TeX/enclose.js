/*
 *  /MathJax/extensions/TeX/enclose.js
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

MathJax.Extension["TeX/enclose"]={version:"2.7.5",ALLOWED:{arrow:1,color:1,mathcolor:1,background:1,mathbackground:1,padding:1,thickness:1}};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var c=MathJax.InputJax.TeX,a=MathJax.ElementJax.mml,b=MathJax.Extension["TeX/enclose"].ALLOWED;c.Definitions.Add({macros:{enclose:"Enclose"}},null,true);c.Parse.Augment({Enclose:function(g){var k=this.GetArgument(g),e=this.GetBrackets(g),j=this.ParseArg(g);var l={notation:k.replace(/,/g," ")};if(e){e=e.replace(/ /g,"").split(/,/);for(var h=0,d=e.length;h<d;h++){var f=e[h].split(/[:=]/);if(b[f[0]]){f[1]=f[1].replace(/^"(.*)"$/,"$1");if(f[1]==="true"){f[1]=true}if(f[1]==="false"){f[1]=false}if(f[0]==="arrow"&&f[1]){l.notation=l.notation+" updiagonalarrow"}else{l[f[0]]=f[1]}}}}this.Push(a.menclose(j).With(l))}});MathJax.Hub.Startup.signal.Post("TeX enclose Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/enclose.js");
