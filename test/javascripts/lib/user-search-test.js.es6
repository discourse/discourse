import userSearch from 'discourse/lib/user-search';

module("lib:user-search");

test("it places groups unconditionally for exact match", function() {
  return userSearch({term: 'team'}).then((results)=>{
     equal(results[results.length-1]["name"], "team");
  });
});
