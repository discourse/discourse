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

    this.set('panelVisible', true);
    andThen(() => {
      assert.ok(!exists(".menu-panel.hidden"), "toggling visible makes it appear");
    });

    click('#outside-area');
    andThen(() => {
      assert.ok(exists(".menu-panel.hidden"), "clicking the body hides the menu");
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

    this.set('panelVisible', true);
    andThen(() => {
      assert.ok(!exists(".menu-panel.hidden"), "toggling visible makes it appear");
    });

    click('#outside-area');
    andThen(() => {
      assert.ok(exists(".menu-panel.hidden"), "clicking the body hides the menu");
      assert.equal(this.get('panelVisible'), false, 'it updates the bound variable');
      this.set('panelVisible', true);
    });

  }
});
