/*
 *  /MathJax/extensions/TeX/action.js
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

MathJax.Extension["TeX/action"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var b=MathJax.InputJax.TeX,a=MathJax.ElementJax.mml;b.Definitions.Add({macros:{toggle:"Toggle",mathtip:"Mathtip",texttip:["Macro","\\mathtip{#1}{\\text{#2}}",2]}},null,true);b.Parse.Augment({Toggle:function(d){var e=[],c;while((c=this.GetArgument(d))!=="\\endtoggle"){e.push(b.Parse(c,this.stack.env).mml())}this.Push(a.maction.apply(a,e).With({actiontype:a.ACTIONTYPE.TOGGLE}))},Mathtip:function(d){var c=this.ParseArg(d),e=this.ParseArg(d);this.Push(a.maction(c,e).With({actiontype:a.ACTIONTYPE.TOOLTIP}))}});MathJax.Hub.Startup.signal.Post("TeX action Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/action.js");
