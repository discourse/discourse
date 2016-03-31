import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({
  basePath() {
    return "/admin/customize/";
  }
});
