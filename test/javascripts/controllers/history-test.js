moduleFor("controller:history");

QUnit.test("displayEdit", async function(assert) {
  const HistoryController = this.subject();

  HistoryController.setProperties({
    model: { last_revision: 3, current_revision: 3, can_edit: false },
    topicController: {}
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

  HistoryController.set("topicController", null);
  assert.equal(
    HistoryController.get("displayEdit"),
    false,
    "it should not display edit button when there is not topic controller"
  );
  HistoryController.set("topicController", {});

  HistoryController.set("model.current_revision", 2);
  assert.equal(
    HistoryController.get("displayEdit"),
    false,
    "it should only display the edit button on the latest revision"
  );

  const html = `<div class="revision-content">
  <p><img src="/uploads/default/original/1X/6b963ffc13cb0c053bbb90c92e99d4fe71b286ef.jpg" alt="" class="diff-del"><img/src=x onerror=alert(document.domain)>" width="276" height="183"></p>
</div>
<aside class="onebox whitelistedgeneric">
  <header class="source">
    <img src="/uploads/default/original/1X/1b0984d7ee08bce90572f46a1950e1ced436d028.png" class="site-icon" width="32" height="32">
    <a href="https://meta.discourse.org/t/discourse-version-2-5/125302">Discourse Meta – 9 Aug 19</a>
  </header>
  <article class="onebox-body">
    <img src="/uploads/default/optimized/1X/ecc92a52ee7353e03d5c0d1ea6521ce4541d9c25_2_500x500.png" class="thumbnail onebox-avatar d-lazyload" width="500" height="500">
    <h3><a href="https://meta.discourse.org/t/discourse-version-2-5/125302" target="_blank">Discourse Version 2.5</a></h3>
    <div style="clear: both"></div>
  </article>
</aside>
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
<aside class="onebox whitelistedgeneric">
  <header class="source">
    <img src="/uploads/default/original/1X/1b0984d7ee08bce90572f46a1950e1ced436d028.png" class="site-icon" width="32" height="32">
    <a href="https://meta.discourse.org/t/discourse-version-2-5/125302">Discourse Meta – 9 Aug 19</a>
  </header>
  <article class="onebox-body">
    <img src="/uploads/default/optimized/1X/ecc92a52ee7353e03d5c0d1ea6521ce4541d9c25_2_500x500.png" class="thumbnail onebox-avatar d-lazyload" width="500" height="500">
    <h3><a href="https://meta.discourse.org/t/discourse-version-2-5/125302" target="_blank">Discourse Version 2.5</a></h3>
    <div style="clear: both"></div>
  </article>
</aside>
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

  await HistoryController.bodyDiffChanged();

  const output = HistoryController.get("bodyDiff");
  assert.equal(
    output,
    expectedOutput,
    "it keeps HTML safe and doesn't strip onebox tags"
  );
});
