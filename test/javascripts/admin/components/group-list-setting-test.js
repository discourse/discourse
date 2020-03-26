import EmberObject from "@ember/object";
import selectKit from "helpers/select-kit-helper";
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
      EmberObject.create({
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
        value: "1"
      })
    );
  },

  async test(assert) {
    const subject = selectKit(".list-setting");

    assert.equal(
      subject.header().value(),
      "1",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("2");

    assert.equal(
      subject.header().value(),
      "1,2",
      "it allows to select a setting from the list of choices"
    );
  }
});
