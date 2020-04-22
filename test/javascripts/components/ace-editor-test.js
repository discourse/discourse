import componentTest from "helpers/component-test";

moduleForComponent("ace-editor", { integration: true });

componentTest("css editor", {
  skip: true,
  template: '{{ace-editor mode="css"}}',
  test(assert) {
    assert.expect(1);
    assert.ok(find(".ace_editor").length, "it renders the ace editor");
  }
});

componentTest("html editor", {
  skip: true,
  template: '{{ace-editor mode="html" content="<b>wat</b>"}}',
  test(assert) {
    assert.expect(1);
    assert.ok(find(".ace_editor").length, "it renders the ace editor");
  }
});

componentTest("sql editor", {
  skip: true,
  template: '{{ace-editor mode="sql" content="SELECT * FROM users"}}',
  test(assert) {
    assert.expect(1);
    assert.ok(find(".ace_editor").length, "it renders the ace editor");
  }
});

componentTest("disabled editor", {
  skip: true,
  template:
    '{{ace-editor mode="sql" content="SELECT * FROM users" disabled=true}}',
  test(assert) {
    const $ace = find(".ace_editor");
    assert.expect(3);
    assert.ok($ace.length, "it renders the ace editor");
    assert.equal(
      $ace
        .parent()
        .data()
        .editor.getReadOnly(),
      true,
      "it sets ACE to read-only mode"
    );
    assert.equal(
      $ace.parent().attr("data-disabled"),
      "true",
      "ACE wrapper has `data-disabled` attribute set to true"
    );
  }
});
