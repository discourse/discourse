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

  const html = `<table>
  <thead>
    <tr>
      <th>Name</th>
      <th style="text-align:left">Test</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Osama</td>
      <td style="text-align:right">Testing</td>
    </tr>
  </tbody>
</table>`;

  HistoryController.setProperties({
    viewMode: "side_by_side",
    model: {
      body_changes: {
        side_by_side: html
      }
    }
  });

  assert.equal(
    HistoryController.get("bodyDiff"),
    html,
    "it doesn't sanitize table html"
  );
});
