export default {
  name: "auth-complete",
  after: "inject-objects",
  initialize() {
    if (window.location.search.indexOf('authComplete=true') !== -1) {
      const lastAuthResult = localStorage.getItem('lastAuthResult');
      if (lastAuthResult) {
        try {
          Discourse.authenticationComplete(JSON.parse(lastAuthResult));
        } catch(e) {
          document.write(`<p>lastAuthResult: ${lastAuthResult}</p>`);
          document.write(e);
        }
      }
    }
  }
};

