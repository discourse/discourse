import { spinnerHTML } from 'discourse/helpers/loading-spinner';
import { bufferedRender } from 'discourse-common/lib/buffered-render';

export default Ember.View.extend(bufferedRender({
  buildBuffer(buffer) {
    buffer.push(spinnerHTML);
  }
}));
