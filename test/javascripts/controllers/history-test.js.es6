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

  const html = `<div class="revision-content">
  <p><img src="/uploads/default/original/1X/6b963ffc13cb0c053bbb90c92e99d4fe71b286ef.jpg" alt="" class="diff-del"><img/src=x onerror=alert(document.domain)>" width="276" height="183"></p>
</div>
<table background="javascript:alert(\"HACKEDXSS\")">
  <thead>
    <tr>
      <th>Column</th>
      <th style="text-align:left">Test</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td background="javascript:alert('HACKEDXSS')">Osama</td>
      <td style="text-align:right">Testing</td>
    </tr>
  </tbody>
</table>`;

  const expectedOutput = `<div class="revision-content">
  <p><img src="/uploads/default/original/1X/6b963ffc13cb0c053bbb90c92e99d4fe71b286ef.jpg" alt class="diff-del">" width="276" height="183"&gt;</p>
</div>
<table>
  <thead>
    <tr>
      <th>Column</th>
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

  HistoryController.bodyDiffChanged().then(() => {
    const output = HistoryController.get("bodyDiff");
    assert.equal(output, expectedOutput, "it keeps safe HTML");
  });
});
