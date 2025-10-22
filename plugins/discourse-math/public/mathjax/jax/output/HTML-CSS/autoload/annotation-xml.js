/*
 *  /MathJax/jax/output/HTML-CSS/autoload/annotation-xml.js
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

MathJax.Hub.Register.StartupHook("HTML-CSS Jax Ready",function(){var c="2.7.5";var a=MathJax.ElementJax.mml,b=MathJax.OutputJax["HTML-CSS"];a["annotation-xml"].Augment({toHTML:function(f){f=this.HTMLhandleSize(this.HTMLcreateSpan(f));var g=this.Get("encoding");for(var e=0,d=this.data.length;e<d;e++){this.data[e].toHTML(f,g)}this.HTMLhandleSpace(f);this.HTMLhandleColor(f);return f},HTMLgetScale:function(){return this.SUPER(arguments).HTMLgetScale.call(this)/b.scale}});a.xml.Augment({toHTML:function(f,g){for(var e=0,d=this.data.length;e<d;e++){f.appendChild(this.data[e].cloneNode(true))}var j=f.bbox;f.bbox=null;j.rw=j.w=b.getW(f);var h=b.getHD(f);j.h=h.h;j.d=h.d;f.bbox=j}});MathJax.Hub.Startup.signal.Post("HTML-CSS annotation-xml Ready");MathJax.Ajax.loadComplete(b.autoloadDir+"/annotation-xml.js")});
