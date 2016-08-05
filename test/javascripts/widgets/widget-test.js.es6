import { moduleForWidget, widgetTest } from 'helpers/widget-test';
import { createWidget } from 'discourse/widgets/widget';
import { withPluginApi } from 'discourse/lib/plugin-api';

moduleForWidget('base');

widgetTest('widget attributes are passed in via args', {
  template: `{{mount-widget widget="hello-test" args=args}}`,

  setup() {
    createWidget('hello-test', {
      tagName: 'div.test',

      html(attrs) {
        return `Hello ${attrs.name}`;
      },
    });

    this.set('args', { name: 'Robin' });
  },

  test(assert) {
    assert.equal(this.$('.test').text(), "Hello Robin");
  }
});

widgetTest('buildClasses', {
  template: `{{mount-widget widget="classname-test" args=args}}`,

  setup() {
    createWidget('classname-test', {
      tagName: 'div.test',

      buildClasses(attrs) {
        return ['static', attrs.dynamic];
      }
    });

    this.set('args', { dynamic: 'cool-class' });
  },

  test(assert) {
    assert.ok(this.$('.test.static.cool-class').length, 'it has all the classes');
  }
});

widgetTest('buildAttributes', {
  template: `{{mount-widget widget="attributes-test" args=args}}`,

  setup() {
    createWidget('attributes-test', {
      tagName: 'div.test',

      buildAttributes(attrs) {
        return { "data-evil": 'trout', "aria-label": attrs.label };
      }
    });

    this.set('args', { label: 'accessibility' });
  },

  test(assert) {
    assert.ok(this.$('.test[data-evil=trout]').length);
    assert.ok(this.$('.test[aria-label=accessibility]').length);
  }
});

widgetTest('buildId', {
  template: `{{mount-widget widget="id-test" args=args}}`,

  setup() {
    createWidget('id-test', {
      buildId(attrs) {
        return `test-${attrs.id}`;
      }
    });

    this.set('args', { id: 1234 });
  },

  test(assert) {
    assert.ok(this.$('#test-1234').length);
  }
});

widgetTest('widget state', {
  template: `{{mount-widget widget="state-test"}}`,

  setup() {
    createWidget('state-test', {
      tagName: 'button.test',
      buildKey: () => `button-test`,

      defaultState() {
        return { clicks: 0 };
      },

      html(attrs, state) {
        return `${state.clicks} clicks`;
      },

      click() {
        this.state.clicks++;
      }
    });
  },

  test(assert) {
    assert.ok(this.$('button.test').length, 'it renders the button');
    assert.equal(this.$('button.test').text(), "0 clicks");

    click(this.$('button'));
    andThen(() => {
      assert.equal(this.$('button.test').text(), "1 clicks");
    });
  }
});

widgetTest('widget update with promise', {
  template: `{{mount-widget widget="promise-test"}}`,

  setup() {
    createWidget('promise-test', {
      tagName: 'button.test',
      buildKey: () => 'promise-test',

      html(attrs, state) {
        return state.name || "No name";
      },

      click() {
        return new Ember.RSVP.Promise(resolve => {
          Ember.run.next(() => {
            this.state.name = "Robin";
            resolve();
          });
        });
      }
    });
  },

  test(assert) {
    assert.equal(this.$('button.test').text(), "No name");

    click(this.$('button'));
    andThen(() => {
      assert.equal(this.$('button.test').text(), "Robin");
    });
  }
});

widgetTest('widget attaching', {
  template: `{{mount-widget widget="attach-test"}}`,

  setup() {
    createWidget('test-embedded', { tagName: 'div.embedded' });

    createWidget('attach-test', {
      tagName: 'div.container',
      html() {
        return this.attach('test-embedded');
      },
    });
  },

  test(assert) {
    assert.ok(this.$('.container').length, "renders container");
    assert.ok(this.$('.container .embedded').length, "renders attached");
  }
});

widgetTest('widget decorating', {
  template: `{{mount-widget widget="decorate-test"}}`,

  setup() {
    createWidget('decorate-test', {
      tagName: 'div.decorate',
      html() {
        return "main content";
      },
    });

    withPluginApi('0.1', api => {
      api.decorateWidget('decorate-test:before', dec => {
        return dec.h('b', 'before');
      });

      api.decorateWidget('decorate-test:after', dec => {
        return dec.h('i', 'after');
      });
    });
  },

  test(assert) {
    assert.ok(this.$('.decorate').length);
    assert.equal(this.$('.decorate b').text(), 'before');
    assert.equal(this.$('.decorate i').text(), 'after');
  }
});

widgetTest('widget settings', {
  template: `{{mount-widget widget="settings-test"}}`,

  setup() {
    createWidget('settings-test', {
      tagName: 'div.settings',

      settings: {
        age: 36
      },

      html() {
        return `age is ${this.settings.age}`;
      },
    });
  },

  test(assert) {
    assert.equal(this.$('.settings').text(), 'age is 36');
  }
});

widgetTest('override settings', {
  template: `{{mount-widget widget="ov-settings-test"}}`,

  setup() {
    createWidget('ov-settings-test', {
      tagName: 'div.settings',

      settings: {
        age: 36
      },

      html() {
        return `age is ${this.settings.age}`;
      },
    });

    withPluginApi('0.1', api => {
      api.changeWidgetSetting('ov-settings-test', 'age', 37);
    });
  },

  test(assert) {
    assert.equal(this.$('.settings').text(), 'age is 37');
  }
});
