import interceptClick from 'discourse/lib/intercept-click';

export default {
  name: "click-interceptor",
  initialize() {
    $('#main').on('click.discourse', 'a', interceptClick);
  }
};
