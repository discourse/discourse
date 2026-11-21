export default function ({ response }) {
  this.get("/discourse-post-event/registration-forms.json", () =>
    response({ registration_forms: [] })
  );
}
