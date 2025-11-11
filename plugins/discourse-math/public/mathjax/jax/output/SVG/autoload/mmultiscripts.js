/*
 *  /MathJax/jax/output/SVG/autoload/mmultiscripts.js
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

MathJax.Hub.Register.StartupHook("SVG Jax Ready",function(){var b="2.7.5";var a=MathJax.ElementJax.mml,c=MathJax.OutputJax.SVG;a.mmultiscripts.Augment({toSVG:function(G,z){this.SVGgetStyles();var B=this.SVG(),N=this.SVGgetScale(B);this.SVGhandleSpace(B);var j=(this.data[this.base]?this.SVGdataStretched(this.base,G,z):c.BBOX.G().Clean());var K=c.TeX.x_height*N,y=c.TeX.scriptspace*N*0.75;var x=this.SVGgetScripts(y);var k=x[0],e=x[1],n=x[2],i=x[3];var g=(this.data[1]||this).SVGgetScale();var C=c.TeX.sup_drop*g,A=c.TeX.sub_drop*g;var o=j.h-C,m=j.d+A,L=0,F;if(j.ic){L=j.ic}if(this.data[this.base]&&(this.data[this.base].type==="mi"||this.data[this.base].type==="mo")){if(c.isChar(this.data[this.base].data.join(""))&&j.scale===1&&!j.stretched&&!this.data[this.base].Get("largeop")){o=m=0}}var H=this.getValues("subscriptshift","superscriptshift"),E=this.SVGgetMu(B);H.subscriptshift=(H.subscriptshift===""?0:c.length2em(H.subscriptshift,E));H.superscriptshift=(H.superscriptshift===""?0:c.length2em(H.superscriptshift,E));var l=0;if(n){l=n.w+L}else{if(i){l=i.w-L}}B.Add(j,Math.max(0,l),0);if(!e&&!i){m=Math.max(m,c.TeX.sub1*N,H.subscriptshift);if(k){m=Math.max(m,k.h-(4/5)*K)}if(n){m=Math.max(m,n.h-(4/5)*K)}if(k){B.Add(k,l+j.w+y-L,-m)}if(n){B.Add(n,0,-m)}}else{if(!k&&!n){var f=this.getValues("displaystyle","texprimestyle");F=c.TeX[(f.displaystyle?"sup1":(f.texprimestyle?"sup3":"sup2"))];o=Math.max(o,F*N,H.superscriptshift);if(e){o=Math.max(o,e.d+(1/4)*K)}if(i){o=Math.max(o,i.d+(1/4)*K)}if(e){B.Add(e,l+j.w+y,o)}if(i){B.Add(i,0,o)}}else{m=Math.max(m,c.TeX.sub2*N);var w=c.TeX.rule_thickness*N;var I=(k||n).h,J=(e||i).d;if(n){I=Math.max(I,n.h)}if(i){J=Math.max(J,i.d)}if((o-J)-(I-m)<3*w){m=3*w-o+J+I;C=(4/5)*K-(o-J);if(C>0){o+=C;m-=C}}o=Math.max(o,H.superscriptshift);m=Math.max(m,H.subscriptshift);if(e){B.Add(e,l+j.w+y,o)}if(i){B.Add(i,l+L-i.w,o)}if(k){B.Add(k,l+j.w+y-L,-m)}if(n){B.Add(n,l-n.w,-m)}}}B.Clean();this.SVGhandleColor(B);this.SVGsaveData(B);var M=this.SVGdata;M.dx=l;M.s=y;M.u=o,M.v=m;M.delta=L;return B},SVGgetScripts:function(r){var p,d,e=[];var o=1,h=this.data.length,g=0;for(var l=0;l<4;l+=2){while(o<h&&(this.data[o]||{}).type!=="mprescripts"){var q=[null,null,null,null];for(var n=l;n<l+2;n++){if(this.data[o]&&this.data[o].type!=="none"&&this.data[o].type!=="mprescripts"){if(!e[n]){e[n]=c.BBOX.G()}q[n]=this.data[o].toSVG()}if((this.data[o]||{}).type!=="mprescripts"){o++}}var f=(l===2);if(f){g+=Math.max((q[l]||{w:0}).w,(q[l+1]||{w:0}).w)}if(q[l]){e[l].Add(q[l].With({x:g-(f?q[l].w:0)}))}if(q[l+1]){e[l+1].Add(q[l+1].With({x:g-(f?q[l+1].w:0)}))}d=e[l]||{w:0};p=e[l+1]||{w:0};d.w=p.w=g=Math.max(d.w,p.w)}o++;g=0}for(n=0;n<4;n++){if(e[n]){e[n].w+=r;e[n].Clean()}}return e}});MathJax.Hub.Startup.signal.Post("SVG mmultiscripts Ready");MathJax.Ajax.loadComplete(c.autoloadDir+"/mmultiscripts.js")});
