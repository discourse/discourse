/*global waitsFor:true expect:true describe:true beforeEach:true it:true sanitizeHtml:true */

describe("sanitize", function(){


  it("strips all script tags", function(){
    var sanitized = sanitizeHtml("<div><script>alert('hi');</script></div>");  

    expect(sanitized)
      .toBe("<div></div>");
  });

  it("strips disallowed attributes", function(){
    var sanitized = sanitizeHtml("<div><p class=\"funky\" wrong='1'>hello</p></div>");

    expect(sanitized)
      .toBe("<div><p class=\"funky\">hello</p></div>");
  });
});


