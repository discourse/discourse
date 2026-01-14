export default {
  initialize(owner) {
    owner.lookup("service:client-error-handler");
    owner.lookup("service:deprecation-warning-handler");
  },
};
