import componentTest from 'helpers/component-test';

moduleForComponent('home-logo', {integration: true});

const bigLogo = '/images/d-logo-sketch.png?test';
const smallLogo = '/images/d-logo-sketch-small.png?test';
const mobileLogo = '/images/d-logo-sketch.png?mobile';
const title = "Cool Forum";

componentTest('basics', {
  template: '{{home-logo minimized=minimized}}',
  setup() {
    this.siteSettings.logo_url = bigLogo;
    this.siteSettings.logo_small_url= smallLogo;
    this.siteSettings.title = title;
    this.set('minimized', false);
  },

  test(assert) {
    assert.ok(this.$('.title').length === 1);
    assert.ok(this.$('a[data-auto-route]').length === 1);

    assert.ok(this.$('img#site-logo.logo-big').length === 1);
    assert.equal(this.$('#site-logo').attr('src'), bigLogo);
    assert.equal(this.$('#site-logo').attr('alt'), title);

    this.set('minimized', true);
    andThen(() => {
      assert.ok(this.$('img.logo-small').length === 1);
      assert.equal(this.$('img.logo-small').attr('src'), smallLogo);
      assert.equal(this.$('img.logo-small').attr('alt'), title);
    });
  }
});

componentTest('no logo', {
  template: '{{home-logo minimized=minimized}}',
  setup() {
    this.siteSettings.logo_url = '';
    this.siteSettings.logo_small_url = '';
    this.siteSettings.title = title;
    this.set('minimized', false);
  },

  test(assert) {
    assert.ok(this.$('a[data-auto-route]').length === 1);

    assert.ok(this.$('h2#site-text-logo.text-logo').length === 1);
    assert.equal(this.$('#site-text-logo').text(), title);

    this.set('minimized', true);
    andThen(() => {
      assert.ok(this.$('i.fa-home').length === 1);
    });
  }
});

componentTest('mobile logo', {
  template: "{{home-logo}}",
  setup() {
    this.siteSettings.mobile_logo_url = mobileLogo;
    this.siteSettings.logo_small_url= smallLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(this.$('img#site-logo.logo-big').length === 1);
    assert.equal(this.$('#site-logo').attr('src'), mobileLogo);
  }
});

componentTest('mobile without logo', {
  template: "{{home-logo}}",
  setup() {
    this.siteSettings.logo_url = bigLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(this.$('img#site-logo.logo-big').length === 1);
    assert.equal(this.$('#site-logo').attr('src'), bigLogo);
  }
});

componentTest("changing url", {
  template: '{{home-logo targetUrl="https://www.discourse.org"}}',
  test(assert) {
    assert.equal(this.$('a').attr('href'), 'https://www.discourse.org');
  }
});
