import Group from 'discourse/models/group';

module("model:group");

test('displayName', function() {
  const group = Group.create({ name: "test", display_name: 'donkey'  });

  ok(group.get('displayName'), "donkey", 'it should return the display name');

  group.set('display_name', null);

  ok(group.get('displayName'), "test", "it should return the group's name");
});
