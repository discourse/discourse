import { createWidget } from 'discourse/widgets/widget';

export default createWidget('emoji', {
  tagName: 'img.emoji',

  buildAttributes(attrs) {
    return { src: Discourse.Emoji.urlFor(attrs.name) };
  },
});
