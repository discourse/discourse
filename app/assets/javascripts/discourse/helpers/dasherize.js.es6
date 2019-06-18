function dasherize([value]) {
  return (value || "").replace(".", "-").dasherize();
}

export default Ember.Helper.helper(dasherize);
