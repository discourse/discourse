import RestAdapter from 'discourse/adapters/rest';
import StaleLocalStorage from 'discourse/mixins/stale-local-storage';

export default RestAdapter.extend(StaleLocalStorage);
