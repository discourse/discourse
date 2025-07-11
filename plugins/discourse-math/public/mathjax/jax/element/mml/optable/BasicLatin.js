/*
 *  /MathJax/jax/element/mml/optable/BasicLatin.js
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

(function(a){var c=a.mo.OPTYPES;var b=a.TEXCLASS;MathJax.Hub.Insert(a.mo.prototype,{OPTABLE:{prefix:{"||":[0,0,b.BIN,{fence:true,stretchy:true,symmetric:true}],"|||":[0,0,b.ORD,{fence:true,stretchy:true,symmetric:true}]},postfix:{"!!":[1,0,b.BIN],"'":c.ACCENT,"++":[0,0,b.BIN],"--":[0,0,b.BIN],"..":[0,0,b.BIN],"...":c.ORD,"||":[0,0,b.BIN,{fence:true,stretchy:true,symmetric:true}],"|||":[0,0,b.ORD,{fence:true,stretchy:true,symmetric:true}]},infix:{"!=":c.BIN4,"&&":c.BIN4,"**":[1,1,b.BIN],"*=":c.BIN4,"+=":c.BIN4,"-=":c.BIN4,"->":c.BIN5,"//":[1,1,b.BIN],"/=":c.BIN4,":=":c.BIN4,"<=":c.BIN5,"<>":[1,1,b.BIN],"==":c.BIN4,">=":c.BIN5,"@":c.ORD11,"||":[2,2,b.BIN,{fence:true,stretchy:true,symmetric:true}],"|||":[2,2,b.ORD,{fence:true,stretchy:true,symmetric:true}]}}});MathJax.Ajax.loadComplete(a.optableDir+"/BasicLatin.js")})(MathJax.ElementJax.mml);
