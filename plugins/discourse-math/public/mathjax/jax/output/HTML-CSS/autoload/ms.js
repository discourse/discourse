/*
 *  /MathJax/jax/output/HTML-CSS/autoload/ms.js
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

MathJax.Hub.Register.StartupHook("HTML-CSS Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml,b=MathJax.OutputJax["HTML-CSS"];a.ms.Augment({toHTML:function(e){e=this.HTMLhandleSize(this.HTMLcreateSpan(e));var d=this.getValues("lquote","rquote","mathvariant");if(!this.hasValue("lquote")||d.lquote==='"'){d.lquote="\u201C"}if(!this.hasValue("rquote")||d.rquote==='"'){d.rquote="\u201D"}if(d.lquote==="\u201C"&&d.mathvariant==="monospace"){d.lquote='"'}if(d.rquote==="\u201D"&&d.mathvariant==="monospace"){d.rquote='"'}var f=d.lquote+this.data.join("")+d.rquote;this.HTMLhandleVariant(e,this.HTMLgetVariant(),f);this.HTMLhandleSpace(e);this.HTMLhandleColor(e);this.HTMLhandleDir(e);return e}});MathJax.Hub.Startup.signal.Post("HTML-CSS ms Ready");MathJax.Ajax.loadComplete(b.autoloadDir+"/ms.js")});
