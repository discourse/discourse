import Mobile from 'discourse/lib/mobile';

// Initializes the `Mobile` helper object.
export default {
  name: 'mobile',
  after: 'inject-objects',

  initialize(container, app) {
    Mobile.init();
    const site = container.lookup('site:main');

    site.set('mobileView', Mobile.mobileView);
    site.set('isMobileDevice', Mobile.isMobileDevice);

    // This is a bit weird but you can't seem to inject into the resolver?
    app.registry.resolver.__resolver__.mobileView = Mobile.mobileView;
  }
};
