import componentTest from 'helpers/component-test';
moduleForComponent('menu-panel', {integration: true});

componentTest('as a dropdown', {
  template: `
    <div id='outside-area'>click me</div>

    <div class='menu-selected'></div>

    {{#menu-panel visible=panelVisible markActive=".menu-selected" force="drop-down"}}
      Some content
    {{/menu-panel}}
  `,

  setup() {
    this.set('panelVisible', false);
  },

  test(assert) {
    assert.ok(exists(".menu-panel.hidden"), "hidden by default");
    assert.ok(!exists(".menu-selected.active"), "does not mark anything as active");

    this.set('panelVisible', true);
    andThen(() => {
      assert.ok(!exists('.menu-panel .close-panel'), "the close X is not shown");
      assert.ok(!exists(".menu-panel.hidden"), "toggling visible makes it appear");
      assert.ok(exists(".menu-selected.active"), "marks the panel as active");
    });

    click('#outside-area')
    andThen(() => {
      assert.ok(exists(".menu-panel.hidden"), "clicking the body hides the menu");
      assert.ok(!exists(".menu-selected.active"), "removes the active class");
      assert.equal(this.get('panelVisible'), false, 'it updates the bound variable');
    });
  }
});

componentTest('as a slide-in', {
  template: `
    <div id='outside-area'>click me</div>
    <div class='menu-selected'></div>

    {{#menu-panel visible=panelVisible markActive=".menu-selected" force="slide-in"}}
      Some content
    {{/menu-panel}}
  `,

  setup() {
    this.set('panelVisible', false);
  },

  test(assert) {
    assert.ok(exists(".menu-panel.hidden"), "hidden by default");
    assert.ok(!exists(".menu-selected.active"), "does not mark anything as active");

    this.set('panelVisible', true);
    andThen(() => {
      assert.ok(!exists(".menu-panel.hidden"), "toggling visible makes it appear");
      assert.ok(!exists(".menu-selected.active"), "slide ins don't mark as active");
    });

    click('#outside-area')
    andThen(() => {
      assert.ok(exists(".menu-panel.hidden"), "clicking the body hides the menu");
      assert.equal(this.get('panelVisible'), false, 'it updates the bound variable');
      this.set('panelVisible', true);
    });

    andThen(() => {
      assert.ok(exists('.menu-panel .close-panel'), "the close X is shown");
    });

    click('.close-panel');
    andThen(() => {
      assert.ok(exists(".menu-panel.hidden"), "clicking the close button closes it");
      assert.equal(this.get('panelVisible'), false, 'it updates the bound variable');
    });
  }
});
