desc "download latest version of highlight and prepare it"
task "highlightjs:update" do

  def run(cmd, opts={})
    puts cmd
    system(cmd, opts.merge(out: $stdout, err: :out))
  end
  run("cd tmp && rm -fr highlight.js && git clone --depth 1 https://github.com/isagalaev/highlight.js.git")
  run("cd tmp && rm -fr highlight_distrib && mkdir -p highlight_distrib/lang")
  run("cd tmp/highlight.js && npm install")
  run("cd tmp/highlight.js && node tools/build.js -t cdn none")

  run("mv tmp/highlight.js/build/highlight.min.js tmp/highlight_distrib/highlight.js")

  run("cd tmp/highlight.js && npm install && node tools/build.js -t cdn")

  Dir.glob("tmp/highlight.js/build/languages/*.min.js") do |path|
    lang = File.basename(path)[0..-8]
    run("mv #{path} tmp/highlight_distrib/lang/#{lang}.js")
  end

  run("rm -fr lib/highlight_js/assets")
  run("mv tmp/highlight_distrib lib/highlight_js/assets")

end
