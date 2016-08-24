
module("Acceptance: wizard");

test("Wizard loads", assert => {
  visit("/");
  andThen(() => {
    assert.ok(exists('.wizard-column-contents'));
    assert.equal(currentPath(), 'steps');
  });
});
