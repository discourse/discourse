import AdminUser from "admin/models/admin-user";
import ApiKey from "admin/models/api-key";

QUnit.module("model:admin-user");

QUnit.test("generate key", function(assert) {
  assert.expect(2);

  var adminUser = AdminUser.create({ id: 333 });
  assert.ok(!adminUser.get("api_key"), "it has no api key by default");
  return adminUser.generateApiKey().then(function() {
    assert.present(adminUser.get("api_key"), "it has an api_key now");
  });
});

QUnit.test("revoke key", function(assert) {
  assert.expect(2);

  var apiKey = ApiKey.create({ id: 1234, key: "asdfasdf" }),
    adminUser = AdminUser.create({ id: 333, api_key: apiKey });

  assert.equal(
    adminUser.get("api_key"),
    apiKey,
    "it has the api key in the beginning"
  );
  return adminUser.revokeApiKey().then(function() {
    assert.blank(adminUser.get("api_key"), "it cleared the api_key");
  });
});
