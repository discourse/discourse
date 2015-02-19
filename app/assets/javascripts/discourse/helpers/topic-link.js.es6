import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('topic-link', function(topic) {
  var title = topic.get('fancy_title');
  return new Handlebars.SafeString("<a href='" + topic.get('lastUnreadUrl') + "' class='title'>" + title + "</a>");
});
