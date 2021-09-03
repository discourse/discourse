hljs.registerLanguage("openscad",(()=>{"use strict";return e=>{const n={
className:"keyword",begin:"\\$(f[asn]|t|vp[rtd]|children)"},r={
className:"number",begin:"\\b\\d+(\\.\\d+)?(e-?\\d+)?",relevance:0
},s=e.inherit(e.QUOTE_STRING_MODE,{illegal:null}),a={className:"function",
beginKeywords:"module function",end:/=|\{/,contains:[{className:"params",
begin:"\\(",end:"\\)",contains:["self",r,s,n,{className:"literal",
begin:"false|true|PI|undef"}]},e.UNDERSCORE_TITLE_MODE]};return{name:"OpenSCAD",
aliases:["scad"],keywords:{
keyword:"function module include use for intersection_for if else \\%",
literal:"false true PI undef",
built_in:"circle square polygon text sphere cube cylinder polyhedron translate rotate scale resize mirror multmatrix color offset hull minkowski union difference intersection abs sign sin cos tan acos asin atan atan2 floor round ceil ln log pow sqrt exp rands min max concat lookup str chr search version version_num norm cross parent_module echo import import_dxf dxf_linear_extrude linear_extrude rotate_extrude surface projection render children dxf_cross dxf_dim let assign"
},contains:[e.C_LINE_COMMENT_MODE,e.C_BLOCK_COMMENT_MODE,r,{className:"meta",
keywords:{keyword:"include use"},begin:"include|use <",end:">"},s,n,{
begin:"[*!#%]",relevance:0},a]}}})());