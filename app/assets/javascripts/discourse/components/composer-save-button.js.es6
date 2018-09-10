import Button from "discourse/components/d-button";

export default Button.extend({
  tabindex: 5,
  classNameBindings: [":btn-primary", ":create", "disableSubmit:disabled"],
  title: "composer.title"
});
