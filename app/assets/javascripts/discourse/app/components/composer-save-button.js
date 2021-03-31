import Button from "discourse/components/d-button";

export default Button.extend({
  classNameBindings: [":btn-primary", ":create", "disableSubmit:disabled"],
  title: "composer.title",
});
