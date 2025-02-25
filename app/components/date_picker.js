@action
setDate(date) {
  const updatedDate = new Date(date);
  const currentDate = this.args.field.value || new Date();

  updatedDate.setHours(
    currentDate.getHours(),
    currentDate.getMinutes(),
    0,
    0
  );

  this.args.field.set(updatedDate);
}
