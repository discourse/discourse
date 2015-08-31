import RestModel from 'discourse/models/rest';
import { fmt } from 'discourse/lib/computed';

export default RestModel.extend({
  detailedName: fmt('id', 'name', '%@ - %@')
});
