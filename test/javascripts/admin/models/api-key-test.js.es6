import { present } from 'helpers/qunit-helpers';
import ApiKey from 'admin/models/api-key';

module("Discourse.ApiKey");

test('create', function() {
  var apiKey = ApiKey.create({id: 123, user: {id: 345}});

  present(apiKey, 'it creates the api key');
  present(apiKey.get('user'), 'it creates the user inside');
});


asyncTestDiscourse('find', function() {
  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve([]));
  ApiKey.find().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/api"), "it GETs the keys");
  });
});

asyncTestDiscourse('generateMasterKey', function() {
  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve({api_key: {}}));
  ApiKey.generateMasterKey().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/api/key", {type: 'POST'}), "it POSTs to create a master key");
  });
});

asyncTestDiscourse('regenerate', function() {
  var apiKey = ApiKey.create({id: 3456});

  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve({api_key: {id: 3456}}));
  apiKey.regenerate().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/api/key", {type: 'PUT', data: {id: 3456}}), "it PUTs the key");
  });
});

asyncTestDiscourse('revoke', function() {
  var apiKey = ApiKey.create({id: 3456});

  sandbox.stub(Discourse, 'ajax').returns(Ember.RSVP.resolve([]));
  apiKey.revoke().then(function() {
    start();
    ok(Discourse.ajax.calledWith("/admin/api/key", {type: 'DELETE', data: {id: 3456}}), "it DELETES the key");
  });
});
