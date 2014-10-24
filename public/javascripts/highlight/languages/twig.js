hljs.registerLanguage('twig', function(hljs) {

  var PARAMS = {
    className: 'params',
    begin: '\\(', end: '\\)'
  };


  var FUNCTION_NAMES = 'attribute block constant cycle date dump include ' +
                  'max min parent random range source template_from_string';

  var FUNCTIONS = {
    className: 'function',
    beginKeywords: FUNCTION_NAMES,
    relevance: 0,
    contains: [
      PARAMS
    ]
  };

  var FILTER = {
    className: 'filter',
    begin: /\|[A-Za-z]+\:?/,
    keywords:
      'abs batch capitalize convert_encoding date date_modify default ' +
      'escape first format join json_encode keys last length lower ' +
      'merge nl2br number_format raw replace reverse round slice sort split ' +
      'striptags title trim upper url_encode',
    contains: [
      FUNCTIONS
    ]
  };


  return {
    aliases: ['craftcms'],
    case_insensitive: true,
    subLanguage: 'xml', subLanguageMode: 'continuous',
    contains: [
      {
        className: 'template_comment',
        begin: /\{#/, end: /#}/
      },

      {
        className: 'template_tag',
        begin: /\{%/, end: /%}/,
        keywords:
          'autoescape block do embed extends filter flush for ' +
          'if import include maro sandbox set spaceless use ' +
          'verbatim',
        contains: [FILTER,FUNCTIONS]
      },
      {
        className: 'variable',
        begin: /\{\{/, end: /}}/,
        contains: [FILTER,FUNCTIONS]
      }
    ]
  };
});
