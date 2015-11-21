import { blank, present } from 'helpers/qunit-helpers';
import AdminUser from 'admin/models/admin-user';
import ApiKey from 'admin/models/api-key';

module("Discourse.AdminUser");

asyncTestDiscourse('generate key', function() {
  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve({api_key: {id: 1234, key: 'asdfasdf'}}));

  var adminUser = AdminUser.create({id: 333});

  blank(adminUser.get('api_key'), 'it has no api key by default');
  adminUser.generateApiKey().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/users/333/generate_api_key", { type: 'POST' }), "it POSTed to the url");
    present(adminUser.get('api_key'), 'it has an api_key now');
  });
});

asyncTestDiscourse('revoke key', function() {

  var apiKey = ApiKey.create({id: 1234, key: 'asdfasdf'}),
      adminUser = AdminUser.create({id: 333, api_key: apiKey});

  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve());

  equal(adminUser.get('api_key'), apiKey, 'it has the api key in the beginning');
  adminUser.revokeApiKey().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/users/333/revoke_api_key", { type: 'DELETE' }), "it DELETEd to the url");
    blank(adminUser.get('api_key'), 'it cleared the api_key');
  });
});
