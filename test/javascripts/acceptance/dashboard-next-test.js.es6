import { acceptance } from "helpers/qunit-helpers";

acceptance("Dashboard Next", {
  loggedIn: true
});

// TODO: jjaffeux to fix
// QUnit.test('Visit dashboard next page', async assert => {
//   await visit('/admin');
//
//   assert.ok(exists('.dashboard-next'), 'has dashboard-next class');
//
//   assert.ok(exists('.admin-report.signups'), 'signups report');
//   assert.ok(exists('.admin-report.posts'), 'posts report');
//   assert.ok(exists('.admin-report.dau-by-mau'), 'dau-by-mau report');
//   assert.ok(
//     exists('.admin-report.daily-engaged-users'),
//     'daily-engaged-users report'
//   );
//   assert.ok(
//     exists('.admin-report.new-contributors'),
//     'new-contributors report'
//   );
//
//   assert.equal(
//     $('.section.dashboard-problems .problem-messages ul li:first-child')
//       .html()
//       .trim(),
//     'Houston...',
//     'displays problems'
//   );
// });
