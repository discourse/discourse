import componentTest from 'helpers/component-test';

moduleForComponent('d-link', {integration: true});

componentTest('basic usage', {
  template: '{{d-link path="/wat" title="user.preferences" icon="gear"}}',
  test(assert) {
    const $a = this.$('a');

    assert.ok($a.length);
    assert.equal($a.attr('href'), '/wat');
    assert.equal($a.attr('title'), I18n.t('user.preferences'));
    assert.equal($a.attr('aria-title'), I18n.t('user.preferences'));
    assert.ok(this.$('i.fa-gear', $a).length, 'shows the icon');
  }
});

componentTest('with a label', {
  template: '{{d-link label="user.preferences"}}',
  test(assert) {
    const $a = this.$('a');
    assert.equal($a.text(), I18n.t('user.preferences'));
  }
});

componentTest('with a label and icon', {
  template: '{{d-link label="user.preferences" icon="gear"}}',
  test(assert) {
    const $a = this.$('a');
    assert.ok(this.$('i.fa-gear', $a).length, 'shows the icon');
    assert.equal($a.text(), ` ${I18n.t('user.preferences')}`, "includes a space");
  }
});

componentTest('block form', {
  template: '{{#d-link path="/test"}}hello world{{/d-link}}',
  test(assert) {
    const $a = this.$('a');
    assert.equal($a.attr('href'), '/test');
    assert.equal($a.text(), 'hello world');
  }
});

componentTest('with an action', {
  template: '{{d-link action="doThing" title="user.preferences" icon="gear"}}',
  test(assert) {
    expect(2);

    assert.ok(this.$('a[href]').length, 'href attribute is present to help with styling');

    this.on('doThing', () => {
      assert.ok(true, 'it fired the action');
    });

    click('a');
  }
});
