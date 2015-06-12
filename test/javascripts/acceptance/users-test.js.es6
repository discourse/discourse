import { acceptance } from "helpers/qunit-helpers";
acceptance("User Directory");

test("Visit Page", function() {
  visit("/users");
  andThen(() => {
    ok(exists('.directory table tr'), "has a list of users");
  });
});

test("Visit All Time", function() {
  visit("/users?period=all");
  andThen(() => {
    ok(exists('.time-read'), "has time read column");
  });
});
