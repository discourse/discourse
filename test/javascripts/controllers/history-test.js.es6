moduleFor("controller:history");

QUnit.test("displayEdit", function(assert) {
  const HistoryController = this.subject();

  HistoryController.setProperties({
    model: { last_revision: 3, current_revision: 3, can_edit: false }
  });

  assert.equal(
    HistoryController.get("displayEdit"),
    false,
    "it should not display edit button when user cannot edit the post"
  );

  HistoryController.set("model.can_edit", true);

  assert.equal(
    HistoryController.get("displayEdit"),
    true,
    "it should display edit button when user can edit the post"
  );

  HistoryController.set("model.current_revision", 2);

  assert.equal(
    HistoryController.get("displayEdit"),
    false,
    "it should only display the edit button on the latest revision"
  );
});
