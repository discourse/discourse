/*
 *  /MathJax/extensions/TeX/extpfeil.js
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

MathJax.Extension["TeX/extpfeil"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var b=MathJax.InputJax.TeX,a=b.Definitions;a.Add({macros:{xtwoheadrightarrow:["Extension","AMSmath"],xtwoheadleftarrow:["Extension","AMSmath"],xmapsto:["Extension","AMSmath"],xlongequal:["Extension","AMSmath"],xtofrom:["Extension","AMSmath"],Newextarrow:["Extension","AMSmath"]}},null,true);MathJax.Hub.Register.StartupHook("TeX AMSmath Ready",function(){MathJax.Hub.Insert(a,{macros:{xtwoheadrightarrow:["xArrow",8608,12,16],xtwoheadleftarrow:["xArrow",8606,17,13],xmapsto:["xArrow",8614,6,7],xlongequal:["xArrow",61,7,7],xtofrom:["xArrow",8644,12,12],Newextarrow:"NewExtArrow"}})});b.Parse.Augment({NewExtArrow:function(c){var e=this.GetArgument(c),f=this.GetArgument(c),d=this.GetArgument(c);if(!e.match(/^\\([a-z]+|.)$/i)){b.Error(["NewextarrowArg1","First argument to %1 must be a control sequence name",c])}if(!f.match(/^(\d+),(\d+)$/)){b.Error(["NewextarrowArg2","Second argument to %1 must be two integers separated by a comma",c])}if(!d.match(/^(\d+|0x[0-9A-F]+)$/i)){b.Error(["NewextarrowArg3","Third argument to %1 must be a unicode character number",c])}e=e.substr(1);f=f.split(",");d=parseInt(d);this.setDef(e,["xArrow",d,parseInt(f[0]),parseInt(f[1])])}});MathJax.Hub.Startup.signal.Post("TeX extpfeil Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/extpfeil.js");
