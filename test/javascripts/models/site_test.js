module("Discourse.Site");

test('instance', function(){

  var site = Discourse.Site.instance();

  present(site, "We have a current site singleton");
  present(site.get('categories'), "The instance has a list of categories");
  present(site.get('flagTypes'), "The instance has a list of flag types");
  present(site.get('trustLevels'), "The instance has a list of trust levels");

});