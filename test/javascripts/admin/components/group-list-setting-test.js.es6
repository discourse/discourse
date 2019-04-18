import componentTest from "helpers/component-test";

moduleForComponent("group-list", { integration: true });

componentTest("default", {
  template: "{{site-setting setting=setting}}",

  beforeEach() {
    this.site.groups = [
      {
        id: 1,
        name: "Donuts"
      },
      {
        id: 2,
        name: "Cheese cake"
      }
    ];

    this.set(
      "setting",
      Ember.Object.create({
        allowsNone: undefined,
        category: "foo",
        default: "",
        description: "Choose groups",
        overridden: false,
        placeholder: null,
        preview: null,
        secret: false,
        setting: "foo_bar",
        type: "group_list",
        validValues: undefined,
        value: "Donuts"
      })
    );
  },

  async test(assert) {
    const subject = selectKit(".list-setting");

    assert.equal(
      subject.header().value(),
      "Donuts",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("Cheese cake");

    assert.equal(
      subject.header().value(),
      "Donuts,Cheese cake",
      "it allows to select a setting from the list of choices"
    );
  }
});
