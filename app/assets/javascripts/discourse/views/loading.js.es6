import { spinnerHTML } from 'discourse/helpers/loading-spinner';

export default Ember.View.extend({
  render: function(buffer) {
    buffer.push(spinnerHTML);
  }
});
