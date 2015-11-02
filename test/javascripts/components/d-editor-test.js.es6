import componentTest from 'helpers/component-test';

moduleForComponent('d-editor', {integration: true});

componentTest('preview updates with markdown', {
  template: '{{d-editor value=value}}',

  test(assert) {
    assert.ok(this.$('.d-editor-button-bar').length);
    assert.equal(this.$('.d-editor-preview.hidden').length, 1);

    fillIn('.d-editor-input', 'hello **world**');

    andThen(() => {
      assert.equal(this.get('value'), 'hello **world**');
      assert.equal(this.$('.d-editor-preview.hidden').length, 0);
      assert.equal(this.$('.d-editor-preview').html().trim(), '<p>hello <strong>world</strong></p>');
    });
  }
});

componentTest('preview sanitizes HTML', {
  template: '{{d-editor value=value}}',

  test(assert) {
    this.set('value', `"><svg onload="prompt(/xss/)"></svg>`);
    andThen(() => {
      assert.equal(this.$('.d-editor-preview').html().trim(), '<p>\"&gt;</p>');
    });
  }
});

componentTest('updating the value refreshes the preview', {
  template: '{{d-editor value=value}}',

  setup() {
    this.set('value', 'evil trout');
  },

  test(assert) {
    assert.equal(this.$('.d-editor-preview').html().trim(), '<p>evil trout</p>');

    andThen(() => this.set('value', 'zogstrip'));
    andThen(() => assert.equal(this.$('.d-editor-preview').html().trim(), '<p>zogstrip</p>'));
  }
});

function testCase(title, testFunc) {
  componentTest(title, {
    template: '{{d-editor value=value}}',
    setup() {
      this.set('value', 'hello world.');
    },
    test(assert) {
      const textarea = this.$('textarea.d-editor-input')[0];
      testFunc.call(this, assert, textarea);
    }
  });
}

testCase(`bold button with no selection`, function(assert, textarea) {
  click(`button.bold`);
  andThen(() => {
    const example = I18n.t(`composer.bold_text`);
    assert.equal(this.get('value'), `hello world.**${example}**`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 14 + example.length);
  });
});

testCase(`bold button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get('value'), `hello **world**.`);
    assert.equal(textarea.selectionStart, 8);
    assert.equal(textarea.selectionEnd, 13);
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get('value'), 'hello world.');
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 11);
  });
});

testCase(`bold with a multiline selection`, function (assert, textarea) {
  this.set('value', "hello\n\nworld\n\ntest.");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 12;
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get('value'), `**hello**\n\n**world**\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 20);
  });

  click(`button.bold`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\nworld\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`italic button with no selection`, function(assert, textarea) {
  click(`button.italic`);
  andThen(() => {
    const example = I18n.t(`composer.italic_text`);
    assert.equal(this.get('value'), `hello world.*${example}*`);

    assert.equal(textarea.selectionStart, 13);
    assert.equal(textarea.selectionEnd, 13 + example.length);
  });
});

testCase(`italic button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get('value'), `hello *world*.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get('value'), 'hello world.');
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 11);
  });
});

testCase(`italic with a multiline selection`, function (assert, textarea) {
  this.set('value', "hello\n\nworld\n\ntest.");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 12;
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get('value'), `*hello*\n\n*world*\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 16);
  });

  click(`button.italic`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\nworld\n\ntest.`);
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase('link modal (cancel)', function(assert) {
  assert.equal(this.$('.insert-link.hidden').length, 1);

  click('button.link');
  andThen(() => {
    assert.equal(this.$('.insert-link.hidden').length, 0);
  });

  click('.insert-link button.btn-danger');
  andThen(() => {
    assert.equal(this.$('.insert-link.hidden').length, 1);
    assert.equal(this.get('value'), 'hello world.');
  });
});

testCase('link modal (simple link)', function(assert) {
  click('button.link');
  fillIn('.insert-link input', 'http://eviltrout.com');
  click('.insert-link button.btn-primary');
  andThen(() => {
    assert.equal(this.$('.insert-link.hidden').length, 1);
    assert.equal(this.get('value'), 'hello world.[http://eviltrout.com](http://eviltrout.com)');
  });
});

testCase('link modal (link with description)', function(assert) {
  click('button.link');
  fillIn('.insert-link input', 'http://eviltrout.com "evil trout"');
  click('.insert-link button.btn-primary');
  andThen(() => {
    assert.equal(this.$('.insert-link.hidden').length, 1);
    assert.equal(this.get('value'), 'hello world.[evil trout](http://eviltrout.com)');
  });
});

componentTest('code button', {
  template: '{{d-editor value=value}}',
  setup() {
    this.set('value', "first line\n\nsecond line\n\nthird line");
  },

  test(assert) {
    const textarea = this.$('textarea.d-editor-input')[0];

    click('button.code');
    andThen(() => {
      assert.equal(this.get('value'), "first line\n\nsecond line\n\nthird line`" + I18n.t('composer.code_text') + "`");
      this.set('value', "first line\n\nsecond line\n\nthird line");
    });

    andThen(() => {
      textarea.selectionStart = 6;
      textarea.selectionEnd = 10;
    });

    click('button.code');
    andThen(() => {
      assert.equal(this.get('value'), "first `line`\n\nsecond line\n\nthird line");
      assert.equal(textarea.selectionStart, 7);
      assert.equal(textarea.selectionEnd, 11);
    });

    click('button.code');
    andThen(() => {
      assert.equal(this.get('value'), "first line\n\nsecond line\n\nthird line");
      assert.equal(textarea.selectionStart, 6);
      assert.equal(textarea.selectionEnd, 10);

      textarea.selectionStart = 0;
      textarea.selectionEnd = 23;
    });

    click('button.code');
    andThen(() => {
      assert.equal(this.get('value'), "    first line\n\n    second line\n\nthird line");
      assert.equal(textarea.selectionStart, 0);
      assert.equal(textarea.selectionEnd, 31);
    });

    click('button.code');
    andThen(() => {
      assert.equal(this.get('value'), "first line\n\nsecond line\n\nthird line");
      assert.equal(textarea.selectionStart, 0);
      assert.equal(textarea.selectionEnd, 23);
    });
  }
});

testCase('quote button', function(assert, textarea) {
  click('button.quote');
  andThen(() => {
    assert.equal(this.get('value'), 'hello world.');
  });

  andThen(() => {
    textarea.selectionStart = 6;
    textarea.selectionEnd = 11;
  });

  click('button.quote');
  andThen(() => {
    assert.equal(this.get('value'), 'hello > world.');
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 13);
  });

  click('button.quote');
  andThen(() => {
    assert.equal(this.get('value'), 'hello world.');
    assert.equal(textarea.selectionStart, 6);
    assert.equal(textarea.selectionEnd, 11);
  });
});

testCase(`bullet button with no selection`, function(assert, textarea) {
  const example = I18n.t('composer.list_item');

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n* ${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 16 + example.length);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n${example}`);
  });
});

testCase(`bullet button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\n* world\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 14);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\nworld\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`bullet button with a multiple line selection`, function(assert, textarea) {
  this.set('value', "* Hello\n\nWorld\n\nEvil");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 20;
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), "Hello\n\n* World\n\n* Evil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 22);
  });

  click(`button.bullet`);
  andThen(() => {
    assert.equal(this.get('value'), "* Hello\n\nWorld\n\nEvil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 20);
  });
});

testCase(`list button with no selection`, function(assert, textarea) {
  const example = I18n.t('composer.list_item');

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n1. ${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 17 + example.length);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 14 + example.length);
  });
});

testCase(`list button with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\n1. world\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 15);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), `hello\n\nworld\n\n.`);
    assert.equal(textarea.selectionStart, 7);
    assert.equal(textarea.selectionEnd, 12);
  });
});

testCase(`list button with line sequence`, function(assert, textarea) {
  this.set('value', "Hello\n\nWorld\n\nEvil");

  andThen(() => {
    textarea.selectionStart = 0;
    textarea.selectionEnd = 18;
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), "1. Hello\n\n2. World\n\n3. Evil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 27);
  });

  click(`button.list`);
  andThen(() => {
    assert.equal(this.get('value'), "Hello\n\nWorld\n\nEvil");
    assert.equal(textarea.selectionStart, 0);
    assert.equal(textarea.selectionEnd, 18);
  });
});

testCase(`heading button with no selection`, function(assert, textarea) {
  const example = I18n.t('composer.heading_text');

  click(`button.heading`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n## ${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 17 + example.length);
  });

  click(`button.heading`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n${example}`);
    assert.equal(textarea.selectionStart, 14);
    assert.equal(textarea.selectionEnd, 14 + example.length);
  });
});

testCase(`rule with no selection`, function(assert, textarea) {
  click(`button.rule`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n----------\n`);
    assert.equal(textarea.selectionStart, 25);
    assert.equal(textarea.selectionEnd, 25);
  });

  click(`button.rule`);
  andThen(() => {
    assert.equal(this.get('value'), `hello world.\n\n----------\n\n\n----------\n`);
    assert.equal(textarea.selectionStart, 38);
    assert.equal(textarea.selectionEnd, 38);
  });
});

testCase(`rule with a selection`, function(assert, textarea) {
  textarea.selectionStart = 6;
  textarea.selectionEnd = 11;

  click(`button.rule`);
  andThen(() => {
    assert.equal(this.get('value'), `hello \n\n----------\n.`);
    assert.equal(textarea.selectionStart, 19);
    assert.equal(textarea.selectionEnd, 19);
  });
});

testCase(`emoji`, function(assert) {
  assert.equal($('.emoji-modal').length, 0);

  click('button.emoji');
  andThen(() => {
    assert.equal($('.emoji-modal').length, 1);
  });

  click('a[data-group-id=0]');
  click('a[title=grinning]');

  andThen(() => {
    assert.ok($('.emoji-modal').length === 0);
    assert.equal(this.get('value'), 'hello world.:grinning:');
  });
});


