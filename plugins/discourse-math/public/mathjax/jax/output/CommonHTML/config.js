/*
 *  /MathJax/jax/output/CommonHTML/config.js
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

MathJax.OutputJax.CommonHTML=MathJax.OutputJax({id:"CommonHTML",version:"2.7.5",directory:MathJax.OutputJax.directory+"/CommonHTML",extensionDir:MathJax.OutputJax.extensionDir+"/CommonHTML",autoloadDir:MathJax.OutputJax.directory+"/CommonHTML/autoload",fontDir:MathJax.OutputJax.directory+"/CommonHTML/fonts",webfontDir:MathJax.OutputJax.fontDir+"/HTML-CSS",config:{matchFontHeight:true,scale:100,minScaleAdjust:50,mtextFontInherit:false,undefinedFamily:"STIXGeneral,'Cambria Math','Arial Unicode MS',serif",EqnChunk:(MathJax.Hub.Browser.isMobile?20:100),EqnChunkFactor:1.5,EqnChunkDelay:100,linebreaks:{automatic:false,width:"container"}}});if(!MathJax.Hub.config.delayJaxRegistration){MathJax.OutputJax.CommonHTML.Register("jax/mml")}MathJax.OutputJax.CommonHTML.loadComplete("config.js");
