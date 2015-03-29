(function() {

  var BREAK = "<wbr>&#8203;";

  /**
    A class for intelligently breaking up strings at logical points.
  **/
  var BreakString = function(string) {
    this.string = string;
  };

  BreakString.prototype.break = function(hint) {
    var hintPos = [],
        str = this.string;

    if(hint) {
      hint = hint.toLowerCase().split(/\s+/).reverse();
      var current = 0;
      while(hint.length > 0) {
        var word = hint.pop();
        if(word !== str.substr(current, word.length).toLowerCase()) {
          break;
        }
        current += word.length;
        hintPos.push(current);
      }
    }

    var rval = [],
        prev = str[0];
    rval.push(prev);
    for (var i=1;i<str.length;i++) {
      var cur = str[i];
      if(prev.match(/[^0-9]/) && cur.match(/[0-9]/)){
        rval.push(BREAK);
      } else if(i>1 && prev.match(/[A-Z]/) && cur.match(/[a-z]/)){
        rval.pop();
        rval.push(BREAK);
        rval.push(prev);
      } else if(prev.match(/[^A-Za-z0-9]/) && cur.match(/[a-zA-Z0-9]/)){
        rval.push(BREAK);
      } else if(hintPos.indexOf(i) > -1) {
        rval.push(BREAK);
      }

      rval.push(cur);
      prev = cur;
    }
    return rval.join("");
  };

  this.BreakString = BreakString;

}).call(this);
