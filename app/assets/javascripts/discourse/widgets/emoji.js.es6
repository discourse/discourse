import { createWidget } from 'discourse/widgets/widget';
import { emojiUrlFor } from 'discourse/lib/text';

export default createWidget('emoji', {
  tagName: 'img.emoji',

  buildAttributes(attrs) {
    return { src: emojiUrlFor(attrs.name) };
  },
});
