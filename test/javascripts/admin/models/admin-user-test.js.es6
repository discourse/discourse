import { blank, present } from 'helpers/qunit-helpers';
import AdminUser from 'admin/models/admin-user';
import ApiKey from 'admin/models/api-key';

module("model:admin-user");

test('generate key', function() {
  var adminUser = AdminUser.create({id: 333});
  blank(adminUser.get('api_key'), 'it has no api key by default');
  adminUser.generateApiKey().then(function() {
    present(adminUser.get('api_key'), 'it has an api_key now');
  });
});

test('revoke key', function() {

  var apiKey = ApiKey.create({id: 1234, key: 'asdfasdf'}),
      adminUser = AdminUser.create({id: 333, api_key: apiKey});

  equal(adminUser.get('api_key'), apiKey, 'it has the api key in the beginning');
  adminUser.revokeApiKey().then(function() {
    blank(adminUser.get('api_key'), 'it cleared the api_key');
  });
});
