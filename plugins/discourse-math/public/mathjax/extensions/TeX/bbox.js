/*
 *  /MathJax/extensions/TeX/bbox.js
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

MathJax.Extension["TeX/bbox"]={version:"2.7.5"};MathJax.Hub.Register.StartupHook("TeX Jax Ready",function(){var b=MathJax.InputJax.TeX,a=MathJax.ElementJax.mml;b.Definitions.Add({macros:{bbox:"BBox"}},null,true);b.Parse.Augment({BBox:function(e){var p=this.GetBrackets(e,""),o=this.ParseArg(e);var k=p.split(/,/),g,d,c;for(var l=0,j=k.length;l<j;l++){var f=k[l].replace(/^\s+/,"").replace(/\s+$/,"");var n=f.match(/^(\.\d+|\d+(\.\d*)?)(pt|em|ex|mu|px|in|cm|mm)$/);if(n){if(g){b.Error(["MultipleBBoxProperty","%1 specified twice in %2","Padding",e])}var h=this.BBoxPadding(n[1]+n[3]);if(h){g={height:"+"+h,depth:"+"+h,lspace:h,width:"+"+(2*n[1])+n[3]}}}else{if(f.match(/^([a-z0-9]+|\#[0-9a-f]{6}|\#[0-9a-f]{3})$/i)){if(d){b.Error(["MultipleBBoxProperty","%1 specified twice in %2","Background",e])}d=f}else{if(f.match(/^[-a-z]+:/i)){if(c){b.Error(["MultipleBBoxProperty","%1 specified twice in %2","Style",e])}c=this.BBoxStyle(f)}else{if(f!==""){b.Error(["InvalidBBoxProperty","'%1' doesn't look like a color, a padding dimension, or a style",f])}}}}}if(g){o=a.mpadded(o).With(g)}if(d||c){o=a.mstyle(o).With({mathbackground:d,style:c})}this.Push(o)},BBoxStyle:function(c){return c},BBoxPadding:function(c){return c}});MathJax.Hub.Startup.signal.Post("TeX bbox Ready")});MathJax.Ajax.loadComplete("[MathJax]/extensions/TeX/bbox.js");
