/*
 *  /MathJax/jax/output/SVG/config.js
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

MathJax.OutputJax.SVG=MathJax.OutputJax({id:"SVG",version:"2.7.5",directory:MathJax.OutputJax.directory+"/SVG",extensionDir:MathJax.OutputJax.extensionDir+"/SVG",autoloadDir:MathJax.OutputJax.directory+"/SVG/autoload",fontDir:MathJax.OutputJax.directory+"/SVG/fonts",config:{scale:100,minScaleAdjust:50,font:"TeX",blacker:1,mtextFontInherit:false,undefinedFamily:"STIXGeneral,'Arial Unicode MS',serif",addMMLclasses:false,useFontCache:true,useGlobalCache:true,EqnChunk:(MathJax.Hub.Browser.isMobile?10:50),EqnChunkFactor:1.5,EqnChunkDelay:100,linebreaks:{automatic:false,width:"container"},merrorStyle:{fontSize:"90%",color:"#C00",background:"#FF8",border:"1px solid #C00",padding:"3px"},styles:{".MathJax_SVG_Display":{"text-align":"center",margin:"1em 0em"},".MathJax_SVG .MJX-monospace":{"font-family":"monospace"},".MathJax_SVG .MJX-sans-serif":{"font-family":"sans-serif"},"#MathJax_SVG_Tooltip":{"background-color":"InfoBackground",color:"InfoText",border:"1px solid black","box-shadow":"2px 2px 5px #AAAAAA","-webkit-box-shadow":"2px 2px 5px #AAAAAA","-moz-box-shadow":"2px 2px 5px #AAAAAA","-khtml-box-shadow":"2px 2px 5px #AAAAAA",padding:"3px 4px","z-index":401}}}});if(!MathJax.Hub.config.delayJaxRegistration){MathJax.OutputJax.SVG.Register("jax/mml")}MathJax.OutputJax.SVG.loadComplete("config.js");
