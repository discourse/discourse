export default {
  after: "inject-objects",

  initialize(owner) {
    const interfaceColor = owner.lookup("service:interface-color");
    interfaceColor.ensureCorrectMode();
  },
};
