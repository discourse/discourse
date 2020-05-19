import EmberObject from "@ember/object";

export default EmberObject.create({
  reload: function() {
    location.reload();
  }
});
