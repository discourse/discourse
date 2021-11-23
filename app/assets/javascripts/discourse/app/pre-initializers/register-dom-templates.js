export default {
  name: "register-discourse-dom-templates",

  initialize() {
    $('script[type="text/x-handlebars"]').each(function () {
      let $this = $(this);
      let name = $this.attr("name") || $this.data("template-name");

      if (window.console) {
        window.console.log(
          "WARNING: you have a handlebars template named " +
            name +
            " this is an unsupported setup, precompile your templates"
        );
      }
      $this.remove();
    });
  },
};
