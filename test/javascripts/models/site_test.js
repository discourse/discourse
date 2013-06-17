/*global module:true test:true ok:true visit:true expect:true exists:true count:true present:true equal:true */

module("Discourse.Site");

test('instance', function(){

  var site = Discourse.Site.instance();

  present(site, "We have a current site singleton");
  present(site.get('categories'), "The instance has a list of categories");
  present(site.get('flagTypes'), "The instance has a list of flag types");

});