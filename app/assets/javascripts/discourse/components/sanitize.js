// Sam: I wrote this but it is totally unsafe so I ported Google Cajole
//  Thing is Cajole is old and complex (albeit super duper fast) 
//
// I would like this ported to: https://github.com/tautologistics/node-htmlparser , perf tested 
//  and move off cajole
//
// See also: http://stackoverflow.com/questions/14971083/is-jquerys-safe-from-xss
//

// (function( $ ) {
// 
//   var elements = ["a", "abbr", "aside", "b", "bdo", "blockquote", "br", 
//                   "caption", "cite", "code", "col", "colgroup", "dd", "div", 
//                   "del", "dfn", "dl", "dt", "em", "hr", "figcaption", "figure", 
//                   "h1", "h2", "h3", "h4", "h5", "h6", "hgroup", "i", "img", "ins", 
//                   "kbd", "li", "mark", "ol", "p", "pre", "q", "rp", "rt", "ruby", 
//                   "s", "samp", "small", "span", "strike", "strong", "sub", "sup", 
//                   "table", "tbody", "td", "tfoot", "th", "thead", "time", "tr", "u", 
//                   "ul", "var", "wbr"];
// 
//   var attributes = {
//         'all'        : ['dir', 'lang', 'title', 'class'],
//         'aside'      : ['data-post', 'data-full', 'data-topic'],
//         'a'          : ['href'],
//         'blockquote' : ['cite'],
//         'col'        : ['span', 'width'],
//         'colgroup'   : ['span', 'width'],
//         'del'        : ['cite', 'datetime'],
//         'img'        : ['align', 'alt', 'height', 'src', 'width'],
//         'ins'        : ['cite', 'datetime'],
//         'ol'         : ['start', 'reversed', 'type'],
//         'q'          : ['cite'],
//         'span'       : ['style'],
//         'table'      : ['summary', 'width', 'style', 'cellpadding', 'cellspacing'],
//         'td'         : ['abbr', 'axis', 'colspan', 'rowspan', 'width', 'style'],
//         'th'         : ['abbr', 'axis', 'colspan', 'rowspan', 'scope', 'width', 'style'],
//         'time'       : ['datetime', 'pubdate'],
//         'ul'         : ['type']
//     
//   }; 
//   
//   var elementMap = {};
//   jQuery.each(elements, function(idx,e){
//     elementMap[e] = true;
//   });
// 
//   var scrubAttributes = function(e){
//     jQuery.each(e.attributes, function(idx, attr){
// 
//       if(jQuery.inArray(attr.name, attributes.all) === -1 &&
//          jQuery.inArray(attr.name, attributes[e.tagName.toLowerCase()]) === -1) {
//            e.removeAttribute(attr.name);
//          } 
//     });
//     return(e);
//   };
// 
//   var scrubNode = function(e){
//     if (!e.tagName) { return(e); }
//     if(elementMap[e.tagName.toLowerCase()]){
//       return scrubAttributes(e);
//     }
//     else 
//     {
//       return null;
//     }
//   };
// 
//   var scrubTree = function(e) {
//     if (!e) { return; }
//     
//     var clean = scrubNode(e);
//     if(!clean){
//       e.parentNode.removeChild(e);
//     }
//     else {
//       jQuery.each(clean.children, function(idx, inner){
//         scrubTree(inner);
//       });
//     }
//   };
// 
//   $.fn.sanitize = function() {
//     clean = this.filter(function(){
//       return scrubNode(this);
//     }).each(function(){
//       scrubTree(this);
//     });
// 
//     return clean;
//   };
// })( jQuery );
