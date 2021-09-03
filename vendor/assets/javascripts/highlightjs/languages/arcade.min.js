hljs.registerLanguage("arcade",(()=>{"use strict";return e=>{
const n="[A-Za-z_][0-9A-Za-z_]*",a={
keyword:"if for while var new function do return void else break",
literal:"BackSlash DoubleQuote false ForwardSlash Infinity NaN NewLine null PI SingleQuote Tab TextFormatting true undefined",
built_in:"Abs Acos Angle Attachments Area AreaGeodetic Asin Atan Atan2 Average Bearing Boolean Buffer BufferGeodetic Ceil Centroid Clip Console Constrain Contains Cos Count Crosses Cut Date DateAdd DateDiff Day Decode DefaultValue Dictionary Difference Disjoint Distance DistanceGeodetic Distinct DomainCode DomainName Equals Exp Extent Feature FeatureSet FeatureSetByAssociation FeatureSetById FeatureSetByPortalItem FeatureSetByRelationshipName FeatureSetByTitle FeatureSetByUrl Filter First Floor Geometry GroupBy Guid HasKey Hour IIf IndexOf Intersection Intersects IsEmpty IsNan IsSelfIntersecting Length LengthGeodetic Log Max Mean Millisecond Min Minute Month MultiPartToSinglePart Multipoint NextSequenceValue Now Number OrderBy Overlaps Point Polygon Polyline Portal Pow Random Relate Reverse RingIsClockWise Round Second SetGeometry Sin Sort Sqrt Stdev Sum SymmetricDifference Tan Text Timestamp Today ToLocal Top Touches ToUTC TrackCurrentTime TrackGeometryWindow TrackIndex TrackStartTime TrackWindow TypeOf Union UrlEncode Variance Weekday When Within Year "
},t={className:"number",variants:[{begin:"\\b(0[bB][01]+)"},{
begin:"\\b(0[oO][0-7]+)"},{begin:e.C_NUMBER_RE}],relevance:0},i={
className:"subst",begin:"\\$\\{",end:"\\}",keywords:a,contains:[]},r={
className:"string",begin:"`",end:"`",contains:[e.BACKSLASH_ESCAPE,i]}
;i.contains=[e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,r,t,e.REGEXP_MODE]
;const o=i.contains.concat([e.C_BLOCK_COMMENT_MODE,e.C_LINE_COMMENT_MODE])
;return{name:"ArcGIS Arcade",keywords:a,
contains:[e.APOS_STRING_MODE,e.QUOTE_STRING_MODE,r,e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,{
className:"symbol",
begin:"\\$[datastore|feature|layer|map|measure|sourcefeature|sourcelayer|targetfeature|targetlayer|value|view]+"
},t,{begin:/[{,]\s*/,relevance:0,contains:[{begin:n+"\\s*:",returnBegin:!0,
relevance:0,contains:[{className:"attr",begin:n,relevance:0}]}]},{
begin:"("+e.RE_STARTERS_RE+"|\\b(return)\\b)\\s*",keywords:"return",
contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,e.REGEXP_MODE,{
className:"function",begin:"(\\(.*?\\)|"+n+")\\s*=>",returnBegin:!0,
end:"\\s*=>",contains:[{className:"params",variants:[{begin:n},{begin:/\(\s*\)/
},{begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0,keywords:a,contains:o}]}]
}],relevance:0},{beginKeywords:"function",end:/\{/,excludeEnd:!0,
contains:[e.inherit(e.TITLE_MODE,{className:"title.function",begin:n}),{
className:"params",begin:/\(/,end:/\)/,excludeBegin:!0,excludeEnd:!0,contains:o
}],illegal:/\[|%/},{begin:/\$[(.]/}],illegal:/#(?!!)/}}})());