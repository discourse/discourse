hljs.registerLanguage("rsl",(()=>{"use strict";return e=>({name:"RenderMan RSL",
keywords:{
keyword:"float color point normal vector matrix while for if do return else break extern continue",
built_in:"abs acos ambient area asin atan atmosphere attribute calculatenormal ceil cellnoise clamp comp concat cos degrees depth Deriv diffuse distance Du Dv environment exp faceforward filterstep floor format fresnel incident length lightsource log match max min mod noise normalize ntransform opposite option phong pnoise pow printf ptlined radians random reflect refract renderinfo round setcomp setxcomp setycomp setzcomp shadow sign sin smoothstep specular specularbrdf spline sqrt step tan texture textureinfo trace transform vtransform xcomp ycomp zcomp"
},illegal:"</",
contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.QUOTE_STRING_MODE,e.APOS_STRING_MODE,e.C_NUMBER_MODE,{
className:"meta",begin:"#",end:"$"},{className:"class",
beginKeywords:"surface displacement light volume imager",end:"\\("},{
beginKeywords:"illuminate illuminance gather",end:"\\("}]})})());