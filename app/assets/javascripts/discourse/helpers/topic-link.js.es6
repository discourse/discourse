import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('topic-link', function(topic) {
  var title = topic.get('fancyTitle');
  var url = topic.linked_post_number ? topic.urlForPostNumber(topic.linked_post_number) : topic.get('lastUnreadUrl');
  return new Handlebars.SafeString("<a href='" + url + "' class='title'>" + title + "</a>");
});
