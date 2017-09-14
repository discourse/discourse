import componentTest from 'helpers/component-test';

moduleForComponent('dropdown-select-box', { integration: true });

componentTest('the header has a title', {
  template: '{{dropdown-select-box content=content value=value}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ id: 1, text: "apple" }, { id: 2, text: "peach" }]);
  },

  test(assert) {
    andThen(() => {
      assert.equal(find(".select-box-header .btn").attr("title"), "apple", "it has the correct title");
    });

    andThen(() => {
      this.set("value", 2);
      assert.equal(find(".select-box-header .btn").attr("title"), "peach", "it correctly changes the title");
    });
  }
});
