module Highlighter

  @@language_map = {
      "Apache" =>                "apache",
      "Bash" =>                  "bash",
      "C#" =>                    "cs",
      "C++" =>                   "cpp",
      "CSS" =>                   "css",
      "CoffeeScript" =>          "coffeescript",
      "Diff" =>                  "diff",
      "HTML, XML" =>             "xml",
      "HTTP" =>                  "http",
      "Ini" =>                   "ini",
      "JSON" =>                  "json",
      "Java" =>                  "java",
      "JavaScript" =>            "javascript",
      "Makefile" =>              "makefile",
      "Markdown" =>              "markdown",
      "Nginx" =>                 "nginx",
      "Objective C" =>           "objectivec",
      "PHP" =>                   "php",
      "Perl" =>                  "perl",
      "Python" =>                "python",
      "Ruby" =>                  "ruby",
      "SQL" =>                   "sql",
      "1C" =>                    "1c",
      "AVR Assembler" =>         "avrasm",
      "ActionScript" =>          "actionscript",
      "AppleScript" =>           "applescript",
      "AsciiDoc" =>              "asciidoc",
      "AutoHotkey" =>            "autohotkey",
      "Axapta" =>                "axapta",
      "Brainfuck" =>             "brainfuck",
      "CMake" =>                 "cmake",
      "Cap’n Proto" =>           "capnproto",
      "Clojure" =>               "clojure",
      "D" =>                     "d",
      "DOS .bat" =>              "dos",
      "Dart" =>                  "dart",
      "Delphi" =>                "delphi",
      "Django" =>                "django",
      "Dust" =>                  "dust",
      "ERB (Embedded Ruby)" =>   "erb",
      "Elixir" =>                "elixir",
      "Erlang" =>                "erlang",
      "Erlang REPL" =>           "erlang-repl",
      "F#" =>                    "fsharp",
      "FIX" =>                   "fix",
      "G-code (ISO 6983)" =>     "gcode",
      "GLSL" =>                  "glsl",
      "Gherkin" =>               "gherkin",
      "Go" =>                    "go",
      "Gradle" =>                "gradle",
      "Groovy" =>                "groovy",
      "Haml" =>                  "haml",
      "Handlebars" =>            "handlebars",
      "Haskell" =>               "haskell",
      "Haxe" =>                  "haxe",
      "Intel x86 Assembly" =>    "x86asm",
      "Lasso" =>                 "lasso",
      "Less" =>                  "less",
      "Lisp" =>                  "lisp",
      "LiveCode" =>              "livecodeserver",
      "LiveScript" =>            "livescript",
      "Lua" =>                   "lua",
      "MEL" =>                   "mel",
      "Mathematica" =>           "mathematica",
      "Matlab" =>                "matlab",
      "Mizar" =>                 "mizar",
      "Monkey" =>                "monkey",
      "NSIS" =>                  "nsis",
      "Nimrod" =>                "nimrod",
      "Nix" =>                   "nix",
      "OCaml" =>                 "ocaml",
      "Oracle Rules Language" => "ruleslanguage",
      "Oxygene" =>               "oxygene",
      "Parser3" =>               "parser3",
      "PowerShell" =>            "powershell",
      "Processing" =>            "processing",
      "Protocol Buffers" =>      "protobuf",
      "Puppet" =>                "puppet",
      "Python profile" =>        "profile",
      "Q" =>                     "q",
      "R" =>                     "r",
      "RenderMan RIB" =>         "rib",
      "RenderMan RSL" =>         "rsl",
      "Rust" =>                  "rust",
      "SCSS" =>                  "scss",
      "Scala" =>                 "scala",
      "Scheme" =>                "scheme",
      "Scilab" =>                "scilab",
      "Smalltalk" =>             "smalltalk",
      "Stylus" =>                "stylus",
      "Swift" =>                 "swift",
      "Tcl" =>                   "tcl",
      "TeX" =>                   "tex",
      "Thrift" =>                "thrift",
      "Twig" =>                  "twig",
      "TypeScript" =>            "typescript",
      "VB.NET" =>                "vbnet",
      "VBScript" =>              "vbscript",
      "VBScript in HTML" =>      "vbscript-html",
      "VHDL" =>                  "vhdl",
      "Vala" =>                  "vala",
      "Vim Script" =>            "vim",
      "XL" =>                    "xl"
  }

  def self.languages()
    @@language_map
  end

  def self.generate(languages, highlight_all_source)
    language_ids = languages.map{|name| @@language_map[name.strip]}

    pack = File.read(highlight_all_source)
    pack_scanner = StringScanner.new pack
    found_languages = []

    result = [] << pack_scanner.scan(/.+?(?=hljs\.registerLanguage\(")/ )
    while !pack_scanner.eos?
      language_module = pack_scanner.scan_until(/(hljs\.registerLanguage\(".*?)(?=hljs\.|\z)/m)
      language_name = /registerLanguage\("([A-Za-z0-9\-]+)"/.match(language_module)[1]

      if language_ids.include? language_name
        found_languages << language_name
        result << language_module
      end
    end
    if found_languages.size != language_ids.size
      raise "Found languages[#{found_languages.join(',')}] not matching expected languages[#{language_ids.join(',')}]. Ensure #{highlight_all_source} contain the requested languages."
    end
    result.join("\n")
  end

end
