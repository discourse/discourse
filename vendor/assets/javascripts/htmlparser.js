/***********************************************
Copyright 2010 - 2012 Chris Winberry <chris@winberry.net>. All rights reserved.
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.
***********************************************/
/* v2.0.0 */

(function () {

var exports;
if (typeof(module) !== 'undefined' && typeof(module.exports) !== 'undefined') {
    exports = module.exports;
} else {
    exports = {};
    if (!this.Tautologistics) {
        this.Tautologistics = {};
    }
    if (this.Tautologistics.NodeHtmlParser) {
        return;
    }
    this.Tautologistics.NodeHtmlParser = exports;
}

function inherits (ctor, superCtor) {
    var tempCtor = function(){};
    tempCtor.prototype = superCtor.prototype;
    ctor.super_ = superCtor;
    ctor.prototype = new tempCtor();
    ctor.prototype.constructor = ctor;
}

var Mode = {
    Text: 'text',
    Tag: 'tag',
    Attr: 'attr',
    CData: 'cdata',
    Doctype: 'doctype',
    Comment: 'comment'
};

function Parser (builder, options) {
    this._options = options ? options : { };
    // if (this._options.includeLocation === undefined) {
    //     this._options.includeLocation = false; //Include position of element (row, col) on nodes
    // }
    this._validateBuilder(builder);
    var self = this;
    this._builder = builder;
    this.reset();
}

if (typeof(module) !== 'undefined' && typeof(module.exports) !== 'undefined') {

    var Stream = require('stream');
    inherits(Parser, Stream);

    Parser.prototype.writable = true;
    Parser.prototype.write = function(data) {
        if(data instanceof Buffer) {
            data = data.toString();
        }
        this.parseChunk(data);
    };

    Parser.prototype.end = function(data) {
        if (arguments.length) {
            this.write(data);
        }
        this.writable = false;
        this.done();
    };

    Parser.prototype.destroy = function() {
        this.writable = false;
    };

}

    //**Public**//
    Parser.prototype.reset = function Parser$reset () {
        this._state = {
            mode: Mode.Text,
            pos: 0,
            data: null,
            pendingText: null,
            pendingWrite: null,
            lastTag: null,
            isScript: false,
            needData: false,
            output: [],
            done: false//,
            // line: 1,
            // col: 1
        };
        this._builder.reset();
    };

    Parser.prototype.parseChunk = function Parser$parseChunk (chunk) {
        this._state.needData = false;
        this._state.data = (this._state.data !== null) ?
             this._state.data.substr(this.pos) + chunk
             :
            chunk
            ;
        while (this._state.pos < this._state.data.length && !this._state.needData) {
            this._parse(this._state);
        }
    };

    Parser.prototype.parseComplete = function Parser$parseComplete (data) {
        this.reset();
        this.parseChunk(data);
        this.done();
    };

    Parser.prototype.done = function Parser$done () {
        this._state.done = true;
        this._parse(this._state);
        this._flushWrite();
        this._builder.done();
    };

    //**Private**//
    Parser.prototype._validateBuilder = function Parser$_validateBuilder (builder) {
        if ((typeof builder) != "object") {
            throw new Error("Builder is not an object");
        }
        if ((typeof builder.reset) != "function") {
            throw new Error("Builder method 'reset' is invalid");
        }
        if ((typeof builder.done) != "function") {
            throw new Error("Builder method 'done' is invalid");
        }
        if ((typeof builder.write) != "function") {
            throw new Error("Builder method 'write' is invalid");
        }
        if ((typeof builder.error) != "function") {
            throw new Error("Builder method 'error' is invalid");
        }
    };

    Parser.prototype._parse = function Parser$_parse () {
        switch (this._state.mode) {
            case Mode.Text:
                return this._parseText(this._state);
            case Mode.Tag:
                return this._parseTag(this._state);
            case Mode.Attr:
                return this._parseAttr(this._state);
            case Mode.CData:
                return this._parseCData(this._state);
            case Mode.Doctype:
                return this._parseDoctype(this._state);
            case Mode.Comment:
                return this._parseComment(this._state);
        }
    };

    Parser.prototype._writePending = function Parser$_writePending (node) {
        if (!this._state.pendingWrite) {
            this._state.pendingWrite = [];
        }
        this._state.pendingWrite.push(node);
    };

    Parser.prototype._flushWrite = function Parser$_flushWrite () {
        if (this._state.pendingWrite) {
            for (var i = 0, len = this._state.pendingWrite.length; i < len; i++) {
                var node = this._state.pendingWrite[i];
                this._builder.write(node);
            }
            this._state.pendingWrite = null;
        }
    };

    Parser.prototype._write = function Parser$_write (node) {
        this._flushWrite();
        this._builder.write(node);
    };

    Parser._re_parseText_scriptClose = /<\s*\/\s*script/ig;
    Parser.prototype._parseText = function Parser$_parseText () {
        var state = this._state;
        var foundPos;
        if (state.isScript) {
            Parser._re_parseText_scriptClose.lastIndex = state.pos;
            foundPos = Parser._re_parseText_scriptClose.exec(state.data);
            foundPos = (foundPos) ?
                foundPos.index
                :
                -1
                ;
        } else {
            foundPos = state.data.indexOf('<', state.pos);
        }
        var text = (foundPos === -1) ? state.data.substring(state.pos, state.data.length) : state.data.substring(state.pos, foundPos);
        if (foundPos < 0 && state.done) {
            foundPos = state.data.length;
        }
        if (foundPos < 0) {
            if (state.isScript) {
                state.needData = true;
                return;
            }
            if (!state.pendingText) {
                state.pendingText = [];
            }
            state.pendingText.push(state.data.substring(state.pos, state.data.length));
            state.pos = state.data.length;
        } else {
            if (state.pendingText) {
                state.pendingText.push(state.data.substring(state.pos, foundPos));
                text = state.pendingText.join('');
                state.pendingText = null;
            } else {
                text = state.data.substring(state.pos, foundPos);
            }
            if (text !== '') {
                this._write({ type: Mode.Text, data: text });
            }
            state.pos = foundPos + 1;
            state.mode = Mode.Tag;
        }
    };

    Parser.re_parseTag = /\s*(\/?)\s*([^\s>\/]+)(\s*)\??(>?)/g;
    Parser.prototype._parseTag = function Parser$_parseTag () {
        var state = this._state;
        Parser.re_parseTag.lastIndex = state.pos;
        var match = Parser.re_parseTag.exec(state.data);
        if (match) {
            if (!match[1] && match[2].substr(0, 3) === '!--') {
                state.mode = Mode.Comment;
                state.pos += 3;
                return;
            }
            if (!match[1] && match[2].substr(0, 8) === '![CDATA[') {
                state.mode = Mode.CData;
                state.pos += 8;
                return;
            }
            if (!match[1] && match[2].substr(0, 8) === '!DOCTYPE') {
                state.mode = Mode.Doctype;
                state.pos += 8;
                return;
            }
            if (!state.done && (state.pos + match[0].length) === state.data.length) {
                //We're at the and of the data, might be incomplete
                state.needData = true;
                return;
            }
            var raw;
            if (match[4] === '>') {
                state.mode = Mode.Text;
                raw = match[0].substr(0, match[0].length - 1);
            } else {
                state.mode = Mode.Attr;
                raw = match[0];
            }
            state.pos += match[0].length;
            var tag = { type: Mode.Tag, name: match[1] + match[2], raw: raw };
            if (state.mode === Mode.Attr) {
                state.lastTag = tag;
            }
            if (tag.name.toLowerCase() === 'script') {
                state.isScript = true;
            } else if (tag.name.toLowerCase() === '/script') {
                state.isScript = false;
            }
            if (state.mode === Mode.Attr) {
                this._writePending(tag);
            } else {
                this._write(tag);
            }
        } else {
            //TODO: end of tag?
            //TODO: push to pending?
            state.needData = true;
        }
    };

    Parser.re_parseAttr_findName = /\s*([^=<>\s'"\/]+)\s*/g;
    Parser.prototype._parseAttr_findName = function Parser$_parseAttr_findName () {
        Parser.re_parseAttr_findName.lastIndex = this._state.pos;
        var match = Parser.re_parseAttr_findName.exec(this._state.data);
        if (!match) {
            return null;
        }
        if (this._state.pos + match[0].length !== Parser.re_parseAttr_findName.lastIndex) {
            return null;
        }
        return {
              match: match[0]
            , name: match[1]
            };
    };
    Parser.re_parseAttr_findValue = /\s*=\s*(?:'([^']*)'|"([^"]*)"|([^'"\s\/>]+))\s*/g;
    Parser.re_parseAttr_findValue_last = /\s*=\s*['"]?(.*)$/g;
    Parser.prototype._parseAttr_findValue = function Parser$_parseAttr_findValue () {
        var state = this._state;
        Parser.re_parseAttr_findValue.lastIndex = state.pos;
        var match = Parser.re_parseAttr_findValue.exec(state.data);
        if (!match) {
            if (!state.done) {
                return null;
            }
            Parser.re_parseAttr_findValue_last.lastIndex = state.pos;
            match = Parser.re_parseAttr_findValue_last.exec(state.data);
            if (!match) {
                return null;
            }
            return {
                  match: match[0]
                , value: (match[1] !== '') ? match[1] : null
                };
        }
        if (state.pos + match[0].length !== Parser.re_parseAttr_findValue.lastIndex) {
            return null;
        }
        return {
              match: match[0]
            , value: match[1] || match[2] || match[3]
            };
    };
    Parser.re_parseAttr_splitValue = /\s*=\s*['"]?/g;
    Parser.re_parseAttr_selfClose = /(\s*\/\s*)(>?)/g;
    Parser.prototype._parseAttr = function Parser$_parseAttr () {
        var state = this._state;
        var name_data = this._parseAttr_findName(state);
        if (!name_data || name_data.name === '?') {
            Parser.re_parseAttr_selfClose.lastIndex = state.pos;
            var matchTrailingSlash = Parser.re_parseAttr_selfClose.exec(state.data);
            if (matchTrailingSlash && matchTrailingSlash.index === state.pos) {
                if (!state.done && !matchTrailingSlash[2] && state.pos + matchTrailingSlash[0].length === state.data.length) {
                    state.needData = true;
                    return;
                }
                state.lastTag.raw += matchTrailingSlash[1];
                // state.output.push({ type: Mode.Tag, name: '/' + state.lastTag.name, raw: null });
                this._write({ type: Mode.Tag, name: '/' + state.lastTag.name, raw: null });
                state.pos += matchTrailingSlash[1].length;
            }
            var foundPos = state.data.indexOf('>', state.pos);
            if (foundPos < 0) {
                if (state.done) { //TODO: is this needed?
                    state.lastTag.raw += state.data.substr(state.pos);
                    state.pos = state.data.length;
                    return;
                }
                state.needData = true;
            } else {
                // state.lastTag = null;
                state.pos = foundPos + 1;
                state.mode = Mode.Text;
            }
            return;
        }
        if (!state.done && state.pos + name_data.match.length === state.data.length) {
            state.needData = true;
            return null;
        }
        state.pos += name_data.match.length;
        var value_data = this._parseAttr_findValue(state);
        if (value_data) {
            if (!state.done && state.pos + value_data.match.length === state.data.length) {
                state.needData = true;
                state.pos -= name_data.match.length;
                return;
            }
            state.pos += value_data.match.length;
        } else {
            Parser.re_parseAttr_splitValue.lastIndex = state.pos;
            if (Parser.re_parseAttr_splitValue.exec(state.data)) {
                state.needData = true;
                state.pos -= name_data.match.length;
                return;
            }
            value_data = {
                  match: ''
                , value: null
                };
        }
        state.lastTag.raw += name_data.match + value_data.match;

        this._writePending({ type: Mode.Attr, name: name_data.name, data: value_data.value });
    };

    Parser.re_parseCData_findEnding = /\]{1,2}$/;
    Parser.prototype._parseCData = function Parser$_parseCData () {
        var state = this._state;
        var foundPos = state.data.indexOf(']]>', state.pos);
        if (foundPos < 0 && state.done) {
            foundPos = state.data.length;
        }
        if (foundPos < 0) {
            Parser.re_parseCData_findEnding.lastIndex = state.pos;
            var matchPartialCDataEnd = Parser.re_parseCData_findEnding.exec(state.data);
            if (matchPartialCDataEnd) {
                state.needData = true;
                return;
            }
            if (!state.pendingText) {
                state.pendingText = [];
            }
            state.pendingText.push(state.data.substr(state.pos, state.data.length));
            state.pos = state.data.length;
            state.needData = true;
        } else {
            var text;
            if (state.pendingText) {
                state.pendingText.push(state.data.substring(state.pos, foundPos));
                text = state.pendingText.join('');
                state.pendingText = null;
            } else {
                text = state.data.substring(state.pos, foundPos);
            }
            this._write({ type: Mode.CData, data: text });
            state.mode = Mode.Text;
            state.pos = foundPos + 3;
        }
    };

    Parser.prototype._parseDoctype = function Parser$_parseDoctype () {
        var state = this._state;
        var foundPos = state.data.indexOf('>', state.pos);
        if (foundPos < 0 && state.done) {
            foundPos = state.data.length;
        }
        if (foundPos < 0) {
            Parser.re_parseCData_findEnding.lastIndex = state.pos;
            if (!state.pendingText) {
                state.pendingText = [];
            }
            state.pendingText.push(state.data.substr(state.pos, state.data.length));
            state.pos = state.data.length;
            state.needData = true;
        } else {
            var text;
            if (state.pendingText) {
                state.pendingText.push(state.data.substring(state.pos, foundPos));
                text = state.pendingText.join('');
                state.pendingText = null;
            } else {
                text = state.data.substring(state.pos, foundPos);
            }
            this._write({ type: Mode.Doctype, data: text });
            state.mode = Mode.Text;
            state.pos = foundPos + 1;
        }
    };

    Parser.re_parseComment_findEnding = /\-{1,2}$/;
    Parser.prototype._parseComment = function Parser$_parseComment () {
        var state = this._state;
        var foundPos = state.data.indexOf('-->', state.pos);
        if (foundPos < 0 && state.done) {
            foundPos = state.data.length;
        }
        if (foundPos < 0) {
            Parser.re_parseComment_findEnding.lastIndex = state.pos;
            var matchPartialCommentEnd = Parser.re_parseComment_findEnding.exec(state.data);
            if (matchPartialCommentEnd) {
                state.needData = true;
                return;
            }
            if (!state.pendingText) {
                state.pendingText = [];
            }
            state.pendingText.push(state.data.substr(state.pos, state.data.length));
            state.pos = state.data.length;
            state.needData = true;
        } else {
            var text;
            if (state.pendingText) {
                state.pendingText.push(state.data.substring(state.pos, foundPos));
                text = state.pendingText.join('');
                state.pendingText = null;
            } else {
                text = state.data.substring(state.pos, foundPos);
            }
            // state.output.push({ type: Mode.Comment, data: text });
            this._write({ type: Mode.Comment, data: text });
            state.mode = Mode.Text;
            state.pos = foundPos + 3;
        }
    };


function HtmlBuilder (callback, options) {
    this.reset();
    this._options = options ? options : { };
    if (this._options.ignoreWhitespace === undefined) {
        this._options.ignoreWhitespace = false; //Keep whitespace-only text nodes
    }
    if (this._options.includeLocation === undefined) {
        this._options.includeLocation = false; //Include position of element (row, col) on nodes
    }
    if (this._options.verbose === undefined) {
        this._options.verbose = true; //Keep data property for tags and raw property for all
    }
    if (this._options.enforceEmptyTags === undefined) {
        this._options.enforceEmptyTags = true; //Don't allow children for HTML tags defined as empty in spec
    }
    if (this._options.caseSensitiveTags === undefined) {
        this._options.caseSensitiveTags = false; //Lowercase all tag names
    }
    if (this._options.caseSensitiveAttr === undefined) {
        this._options.caseSensitiveAttr = false; //Lowercase all attribute names
    }
    if ((typeof callback) == "function") {
        this._callback = callback;
    }
}

    //**"Static"**//
    //HTML Tags that shouldn't contain child nodes
    HtmlBuilder._emptyTags = {
          area: 1
        , base: 1
        , basefont: 1
        , br: 1
        , col: 1
        , frame: 1
        , hr: 1
        , img: 1
        , input: 1
        , isindex: 1
        , link: 1
        , meta: 1
        , param: 1
        , embed: 1
        , '?xml': 1
    };
    //Regex to detect whitespace only text nodes
    HtmlBuilder.reWhitespace = /^\s*$/;

    //**Public**//
    //Properties//
    HtmlBuilder.prototype.dom = null; //The hierarchical object containing the parsed HTML
    //Methods//
    //Resets the builder back to starting state
    HtmlBuilder.prototype.reset = function HtmlBuilder$reset() {
        this.dom = [];
        // this._raw = [];
        this._done = false;
        this._tagStack = [];
        this._lastTag = null;
        this._tagStack.last = function HtmlBuilder$_tagStack$last () {
            return(this.length ? this[this.length - 1] : null);
        };
        this._line = 1;
        this._col = 1;
    };
    //Signals the builder that parsing is done
    HtmlBuilder.prototype.done = function HtmlBuilder$done () {
        this._done = true;
        this.handleCallback(null);
    };

    HtmlBuilder.prototype.error = function HtmlBuilder$error (error) {
        this.handleCallback(error);
    };

    HtmlBuilder.prototype.handleCallback = function HtmlBuilder$handleCallback (error) {
            if ((typeof this._callback) != "function") {
                if (error) {
                    throw error;
                } else {
                    return;
                }
            }
            this._callback(error, this.dom);
    };

    HtmlBuilder.prototype.isEmptyTag = function HtmlBuilder$isEmptyTag (element) {
        var name = element.name.toLowerCase();
        if (name.charAt(0) == '?') {
            return true;
        }
        if (name.charAt(0) == '/') {
            name = name.substring(1);
        }
        return this._options.enforceEmptyTags && !!HtmlBuilder._emptyTags[name];
    };

    HtmlBuilder.prototype._getLocation = function HtmlBuilder$_getLocation () {
        return { line: this._line, col: this._col };
    };

    // HtmlBuilder.reLineSplit = /(\r\n|\r|\n)/g;
    HtmlBuilder.prototype._updateLocation = function HtmlBuilder$_updateLocation (node) {
        var positionData = (node.type === Mode.Tag) ? node.raw : node.data;
        if (positionData === null) {
            return;
        }
        // var lines = positionData.split(HtmlBuilder.reLineSplit);
        var lines = positionData.split("\n");
        this._line += lines.length - 1;
        if (lines.length > 1) {
            this._col = 1;
        }
        this._col += lines[lines.length - 1].length;
        if (node.type === Mode.Tag) {
            this._col += 2;
        } else if (node.type === Mode.Comment) {
            this._col += 7;
        } else if (node.type === Mode.CData) {
            this._col += 12;
        }
    };

    HtmlBuilder.prototype._copyElement = function HtmlBuilder$_copyElement (element) {
        var newElement = { type: element.type };

        if (this._options.verbose && element['raw'] !== undefined) {
            newElement.raw = element.raw;
        }
        if (element['name'] !== undefined) {
            switch (element.type) {

                case Mode.Tag:
                    newElement.name = this._options.caseSensitiveTags ?
                        element.name
                        :
                        element.name.toLowerCase()
                        ;
                    break;

                case Mode.Attr:
                    newElement.name = this._options.caseSensitiveAttr ?
                        element.name
                        :
                        element.name.toLowerCase()
                        ;
                    break;

                default:
                    newElement.name = this._options.caseSensitiveTags ?
                        element.name
                        :
                        element.name.toLowerCase()
                        ;
                    break;

            }
        }
        if (element['data'] !== undefined) {
            newElement.data = element.data;
        }
        if (element.location) {
            newElement.location = { line: element.location.line, col: element.location.col };
        }

        return newElement;
    };

    HtmlBuilder.prototype.write = function HtmlBuilder$write (element) {
        // this._raw.push(element);
        if (this._done) {
            this.handleCallback(new Error("Writing to the builder after done() called is not allowed without a reset()"));
        }
        if (this._options.includeLocation) {
            if (element.type !== Mode.Attr) {
                element.location = this._getLocation();
                this._updateLocation(element);
            }
        }
        if (element.type === Mode.Text && this._options.ignoreWhitespace) {
            if (HtmlBuilder.reWhitespace.test(element.data)) {
                return;
            }
        }
        var parent;
        var node;
        if (!this._tagStack.last()) { //There are no parent elements
            //If the element can be a container, add it to the tag stack and the top level list
            if (element.type === Mode.Tag) {
                if (element.name.charAt(0) != "/") { //Ignore closing tags that obviously don't have an opening tag
                    node = this._copyElement(element);
                    this.dom.push(node);
                    if (!this.isEmptyTag(node)) { //Don't add tags to the tag stack that can't have children
                        this._tagStack.push(node);
                    }
                    this._lastTag = node;
                }
            } else if (element.type === Mode.Attr && this._lastTag) {
                if (!this._lastTag.attributes) {
                    this._lastTag.attributes = {};
                }
                this._lastTag.attributes[this._options.caseSensitiveAttr ? element.name : element.name.toLowerCase()] =
                    element.data;
            } else { //Otherwise just add to the top level list
                this.dom.push(this._copyElement(element));
            }
        } else { //There are parent elements
            //If the element can be a container, add it as a child of the element
            //on top of the tag stack and then add it to the tag stack
            if (element.type === Mode.Tag) {
                if (element.name.charAt(0) == "/") {
                    //This is a closing tag, scan the tagStack to find the matching opening tag
                    //and pop the stack up to the opening tag's parent
                    var baseName = this._options.caseSensitiveTags ?
                        element.name.substring(1)
                        :
                        element.name.substring(1).toLowerCase()
                        ;
                    if (!this.isEmptyTag(element)) {
                        var pos = this._tagStack.length - 1;
                        while (pos > -1 && this._tagStack[pos--].name != baseName) { }
                        if (pos > -1 || this._tagStack[0].name == baseName) {
                            while (pos < this._tagStack.length - 1) {
                                this._tagStack.pop();
                            }
                        }
                    }
                }
                else { //This is not a closing tag
                    parent = this._tagStack.last();
                    if (element.type === Mode.Attr) {
                        if (!parent.attributes) {
                            parent.attributes = {};
                        }
                        parent.attributes[this._options.caseSensitiveAttr ? element.name : element.name.toLowerCase()] =
                            element.data;
                    } else {
                        node = this._copyElement(element);
                        if (!parent.children) {
                            parent.children = [];
                        }
                        parent.children.push(node);
                        if (!this.isEmptyTag(node)) { //Don't add tags to the tag stack that can't have children
                            this._tagStack.push(node);
                        }
                        if (element.type === Mode.Tag) {
                            this._lastTag = node;
                        }
                    }
                }
            }
            else { //This is not a container element
                parent = this._tagStack.last();
                if (element.type === Mode.Attr) {
                    if (!parent.attributes) {
                        parent.attributes = {};
                    }
                    parent.attributes[this._options.caseSensitiveAttr ? element.name : element.name.toLowerCase()] =
                        element.data;
                } else {
                    if (!parent.children) {
                        parent.children = [];
                    }
                    parent.children.push(this._copyElement(element));
                }
            }
        }
    };


    //**Private**//
    //Properties//
    HtmlBuilder.prototype._options = null; //Builder options for how to behave
    HtmlBuilder.prototype._callback = null; //Callback to respond to when parsing done
    HtmlBuilder.prototype._done = false; //Flag indicating whether builder has been notified of parsing completed
    HtmlBuilder.prototype._tagStack = null; //List of parents to the currently element being processed
    //Methods//


function RssBuilder (callback) {
    RssBuilder.super_.call(this, callback, { ignoreWhitespace: true, verbose: false, enforceEmptyTags: false, caseSensitiveTags: true });
}
inherits(RssBuilder, HtmlBuilder);

    RssBuilder.prototype.done = function RssBuilder$done () {
        var feed = {};
        var feedRoot;

        var found = DomUtils.getElementsByTagName(function (value) { return(value == "rss" || value == "feed"); }, this.dom, false);
        if (found.length) {
            feedRoot = found[0];
        }
        if (feedRoot) {
            if (feedRoot.name == "rss") {
                feed.type = "rss";
                feedRoot = feedRoot.children[0]; //<channel/>
                feed.id = "";
                try {
                    feed.title = DomUtils.getElementsByTagName("title", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.link = DomUtils.getElementsByTagName("link", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.description = DomUtils.getElementsByTagName("description", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.updated = new Date(DomUtils.getElementsByTagName("lastBuildDate", feedRoot.children, false)[0].children[0].data);
                } catch (ex) { }
                try {
                    feed.author = DomUtils.getElementsByTagName("managingEditor", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                feed.items = [];
                DomUtils.getElementsByTagName("item", feedRoot.children).forEach(function (item, index, list) {
                    var entry = {};
                    try {
                        entry.id = DomUtils.getElementsByTagName("guid", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.title = DomUtils.getElementsByTagName("title", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.link = DomUtils.getElementsByTagName("link", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.description = DomUtils.getElementsByTagName("description", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.pubDate = new Date(DomUtils.getElementsByTagName("pubDate", item.children, false)[0].children[0].data);
                    } catch (ex) { }
                    feed.items.push(entry);
                });
            } else {
                feed.type = "atom";
                try {
                    feed.id = DomUtils.getElementsByTagName("id", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.title = DomUtils.getElementsByTagName("title", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.link = DomUtils.getElementsByTagName("link", feedRoot.children, false)[0].attributes.href;
                } catch (ex) { }
                try {
                    feed.description = DomUtils.getElementsByTagName("subtitle", feedRoot.children, false)[0].children[0].data;
                } catch (ex) { }
                try {
                    feed.updated = new Date(DomUtils.getElementsByTagName("updated", feedRoot.children, false)[0].children[0].data);
                } catch (ex) { }
                try {
                    feed.author = DomUtils.getElementsByTagName("email", feedRoot.children, true)[0].children[0].data;
                } catch (ex) { }
                feed.items = [];
                DomUtils.getElementsByTagName("entry", feedRoot.children).forEach(function (item, index, list) {
                    var entry = {};
                    try {
                        entry.id = DomUtils.getElementsByTagName("id", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.title = DomUtils.getElementsByTagName("title", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.link = DomUtils.getElementsByTagName("link", item.children, false)[0].attributes.href;
                    } catch (ex) { }
                    try {
                        entry.description = DomUtils.getElementsByTagName("summary", item.children, false)[0].children[0].data;
                    } catch (ex) { }
                    try {
                        entry.pubDate = new Date(DomUtils.getElementsByTagName("updated", item.children, false)[0].children[0].data);
                    } catch (ex) { }
                    feed.items.push(entry);
                });
            }

            this.dom = feed;
        }
        RssBuilder.super_.prototype.done.call(this);
    };

    var DomUtils = {
          testElement: function DomUtils$testElement (options, element) {
            if (!element) {
                return false;
            }

            for (var key in options) {
                if (!options.hasOwnProperty(key)) {
                    continue;
                }
                if (key == "tag_name") {
                    if (element.type !== Mode.Tag) {
                        return false;
                    }
                    if (!options["tag_name"](element.name)) {
                        return false;
                    }
                } else if (key == "tag_type") {
                    if (!options["tag_type"](element.type)) {
                        return false;
                    }
                } else if (key == "tag_contains") {
                    if (element.type !== Mode.Text && element.type !== Mode.Comment && element.type !== Mode.CData) {
                        return false;
                    }
                    if (!options["tag_contains"](element.data)) {
                        return false;
                    }
                } else {
                    if (!element.attributes || !options[key](element.attributes[key])) {
                        return false;
                    }
                }
            }

            return true;
        }

        , getElements: function DomUtils$getElements (options, currentElement, recurse, limit) {
            recurse = (recurse === undefined || recurse === null) || !!recurse;
            limit = isNaN(parseInt(limit)) ? -1 : parseInt(limit);

            if (!currentElement) {
                return([]);
            }

            var found = [];
            var elementList;

            function getTest (checkVal) {
                return function (value) {
                    return(value == checkVal);
                };
            }
            for (var key in options) {
                if ((typeof options[key]) != "function") {
                    options[key] = getTest(options[key]);
                }
            }

            if (DomUtils.testElement(options, currentElement)) {
                found.push(currentElement);
            }

            if (limit >= 0 && found.length >= limit) {
                return(found);
            }

            if (recurse && currentElement.children) {
                elementList = currentElement.children;
            } else if (currentElement instanceof Array) {
                elementList = currentElement;
            } else {
                return(found);
            }

            for (var i = 0; i < elementList.length; i++) {
                found = found.concat(DomUtils.getElements(options, elementList[i], recurse, limit));
                if (limit >= 0 && found.length >= limit) {
                    break;
                }
            }

            return(found);
        }

        , getElementById: function DomUtils$getElementById (id, currentElement, recurse) {
            var result = DomUtils.getElements({ id: id }, currentElement, recurse, 1);
            return(result.length ? result[0] : null);
        }

        , getElementsByTagName: function DomUtils$getElementsByTagName (name, currentElement, recurse, limit) {
            return(DomUtils.getElements({ tag_name: name }, currentElement, recurse, limit));
        }

        , getElementsByTagType: function DomUtils$getElementsByTagType (type, currentElement, recurse, limit) {
            return(DomUtils.getElements({ tag_type: type }, currentElement, recurse, limit));
        }
    };

exports.Parser = Parser;

exports.HtmlBuilder = HtmlBuilder;

exports.RssBuilder = RssBuilder;

exports.ElementType = Mode;

exports.DomUtils = DomUtils;

})();
