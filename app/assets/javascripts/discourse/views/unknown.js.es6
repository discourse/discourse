import { bufferedRender } from 'discourse-common/lib/buffered-render';

export default Ember.View.extend(bufferedRender({
  classNameBindings: [':container'],

  buildBuffer(buffer) {
    buffer.push(this.get('controller.model'));
  }
}));
