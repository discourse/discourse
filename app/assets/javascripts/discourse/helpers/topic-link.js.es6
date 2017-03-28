import { registerUnbound } from 'discourse-common/lib/helpers';

registerUnbound('topic-link', (topic, args) => {
  const title = topic.get('fancyTitle');
  const url = topic.linked_post_number ?
    topic.urlForPostNumber(topic.linked_post_number) :
    topic.get('lastUnreadUrl');

  const classes = ['title'];
  if (topic.get('last_read_post_number') === topic.get('highest_post_number')) {
    classes.push('visited');
  }

  if (args.class) {
    args.class.split(" ").forEach(c => classes.push(c));
  }

  const result = `<a href='${url}' class='${classes.join(' ')}'>${title}</a>`;
  return new Handlebars.SafeString(result);
});
