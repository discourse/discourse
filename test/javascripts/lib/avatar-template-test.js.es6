import avatarTemplate from 'discourse/lib/avatar-template';

module('lib:avatar-template');

test("avatarTemplate", function(){
  var oldCDN = Discourse.CDN;
  var oldBase = Discourse.BaseUrl;
  Discourse.BaseUrl = "frogs.com";

  equal(avatarTemplate("sam", 1), "/user_avatar/frogs.com/sam/{size}/1.png");
  Discourse.CDN = "http://awesome.cdn.com";
  equal(avatarTemplate("sam", 1), "http://awesome.cdn.com/user_avatar/frogs.com/sam/{size}/1.png");
  Discourse.CDN = oldCDN;
  Discourse.BaseUrl = oldBase;
});

