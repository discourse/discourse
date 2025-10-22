/*
 *  /MathJax/jax/output/HTML-CSS/config.js
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

MathJax.OutputJax["HTML-CSS"]=MathJax.OutputJax({id:"HTML-CSS",version:"2.7.5",directory:MathJax.OutputJax.directory+"/HTML-CSS",extensionDir:MathJax.OutputJax.extensionDir+"/HTML-CSS",autoloadDir:MathJax.OutputJax.directory+"/HTML-CSS/autoload",fontDir:MathJax.OutputJax.directory+"/HTML-CSS/fonts",webfontDir:MathJax.OutputJax.fontDir+"/HTML-CSS",config:{noReflows:true,matchFontHeight:true,scale:100,minScaleAdjust:50,availableFonts:["STIX","TeX"],preferredFont:"TeX",webFont:"TeX",imageFont:"TeX",undefinedFamily:"STIXGeneral,'Arial Unicode MS',serif",mtextFontInherit:false,EqnChunk:(MathJax.Hub.Browser.isMobile?10:50),EqnChunkFactor:1.5,EqnChunkDelay:100,linebreaks:{automatic:false,width:"container"},styles:{".MathJax_Display":{"text-align":"center",margin:"1em 0em"},".MathJax .merror":{"background-color":"#FFFF88",color:"#CC0000",border:"1px solid #CC0000",padding:"1px 3px","font-style":"normal","font-size":"90%"},".MathJax .MJX-monospace":{"font-family":"monospace"},".MathJax .MJX-sans-serif":{"font-family":"sans-serif"},"#MathJax_Tooltip":{"background-color":"InfoBackground",color:"InfoText",border:"1px solid black","box-shadow":"2px 2px 5px #AAAAAA","-webkit-box-shadow":"2px 2px 5px #AAAAAA","-moz-box-shadow":"2px 2px 5px #AAAAAA","-khtml-box-shadow":"2px 2px 5px #AAAAAA",filter:"progid:DXImageTransform.Microsoft.dropshadow(OffX=2, OffY=2, Color='gray', Positive='true')",padding:"3px 4px","z-index":401}}}});if(MathJax.Hub.Browser.isMSIE&&document.documentMode>=9){delete MathJax.OutputJax["HTML-CSS"].config.styles["#MathJax_Tooltip"].filter}if(!MathJax.Hub.config.delayJaxRegistration){MathJax.OutputJax["HTML-CSS"].Register("jax/mml")}MathJax.Hub.Register.StartupHook("End Config",[function(b,c){var a=b.Insert({minBrowserVersion:{Firefox:3,Opera:9.52,MSIE:6,Chrome:0.3,Safari:2,Konqueror:4},inlineMathDelimiters:["$","$"],displayMathDelimiters:["$$","$$"],multilineDisplay:true,minBrowserTranslate:function(f){var e=b.getJaxFor(f),k=["[Math]"],j;var h=document.createElement("span",{className:"MathJax_Preview"});if(e.inputJax==="TeX"){if(e.root.Get("displaystyle")){j=a.displayMathDelimiters;k=[j[0]+e.originalText+j[1]];if(a.multilineDisplay){k=k[0].split(/\n/)}}else{j=a.inlineMathDelimiters;k=[j[0]+e.originalText.replace(/^\s+/,"").replace(/\s+$/,"")+j[1]]}}for(var g=0,d=k.length;g<d;g++){h.appendChild(document.createTextNode(k[g]));if(g<d-1){h.appendChild(document.createElement("br"))}}f.parentNode.insertBefore(h,f)}},(b.config["HTML-CSS"]||{}));if(b.Browser.version!=="0.0"&&!b.Browser.versionAtLeast(a.minBrowserVersion[b.Browser]||0)){c.Translate=a.minBrowserTranslate;b.Config({showProcessingMessages:false});MathJax.Message.Set(["MathJaxNotSupported","Your browser does not support MathJax"],null,4000);b.Startup.signal.Post("MathJax not supported")}},MathJax.Hub,MathJax.OutputJax["HTML-CSS"]]);MathJax.OutputJax["HTML-CSS"].loadComplete("config.js");
