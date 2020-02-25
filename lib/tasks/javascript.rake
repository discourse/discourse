# frozen_string_literal: true

def public_js
  "#{Rails.root}/public/javascripts"
end

def vendor_js
  "#{Rails.root}/vendor/assets/javascripts"
end

def library_src
  "#{Rails.root}/node_modules"
end

task 'javascript:update' do

  require 'uglifier'

  yarn = system("yarn install")
  abort('Unable to run "yarn install"') unless yarn

  dependencies = [
    {
      source: 'bootstrap/js/modal.js',
      destination: 'bootstrap-modal.js'
    }, {
      source: 'ace-builds/src-min-noconflict/.',
      destination: 'ace',
      public: true
    }, {
      source: 'chart.js/dist/Chart.min.js',
      public: true
    }, {
      source: 'magnific-popup/dist/jquery.magnific-popup.min.js',
      public: true
    }, {
      source: 'pikaday/pikaday.js',
      public: true
    }, {
      source: 'spectrum-colorpicker/spectrum.js',
      uglify: true,
      public: true
    }, {
      source: 'spectrum-colorpicker/spectrum.css',
      public: true
    }, {
      source: 'favcount/favcount.js'
    }, {
      source: 'handlebars/dist/handlebars.js'
    }, {
      source: 'handlebars/dist/handlebars.runtime.js'
    }, {
      source: 'highlight.js/build/.',
      destination: 'highlightjs'
    }, {
      source: 'jquery-resize/jquery.ba-resize.js'
    }, {
      source: 'jquery.autoellipsis/src/jquery.autoellipsis.js',
      destination: 'jquery.autoellipsis-1.0.10.js'
    }, {
      source: 'jquery-color/dist/jquery.color.js'
    }, {
      source: 'jquery.cookie/jquery.cookie.js'
    }, {
      source: 'jquery/dist/jquery.js'
    }, {
      source: 'jquery-tags-input/src/jquery.tagsinput.js'
    }, {
      source: 'markdown-it/dist/markdown-it.js'
    }, {
      source: 'mousetrap/mousetrap.js'
    }, {
      source: 'moment/moment.js'
    }, {
      source: 'moment/locale/.',
      destination: 'moment-locale',
    }, {
      source: 'moment-timezone/builds/moment-timezone-with-data-10-year-range.js',
      destination: 'moment-timezone-with-data.js'
    }, {
      source: 'lodash.js',
      destination: 'lodash.js'
    }, {
      source: 'moment-timezone-names-translations/locales/.',
      destination: 'moment-timezone-names-locale'
    }, {
      source: 'mousetrap/plugins/global-bind/mousetrap-global-bind.js'
    }, {
      source: 'resumablejs/resumable.js'
    }, {
      # TODO: drop when we eventually drop IE11, this will land in iOS in version 13
      source: 'intersection-observer/intersection-observer.js'
    }, {
      source: 'workbox-sw/build/.',
      destination: 'workbox',
      public: true
    }, {
      source: 'workbox-routing/build/.',
      destination: 'workbox',
      public: true
    }, {
      source: 'workbox-core/build/.',
      destination: 'workbox',
      public: true
    }, {
      source: 'workbox-strategies/build/.',
      destination: 'workbox',
      public: true
    }, {
      source: 'workbox-expiration/build/.',
      destination: 'workbox',
      public: true
    }, {
      source: '@popperjs/core/dist/umd/popper.js'
    }
  ]

  start = Time.now

  dependencies.each do |f|
    src = "#{library_src}/#{f[:source]}"

    unless f[:destination]
      filename = f[:source].split("/").last
    else
      filename = f[:destination]
    end

    # Highlight.js needs building
    if src.include? "highlight.js"
      puts "Install Highlight.js dependencies"
      system("cd node_modules/highlight.js && yarn install")

      puts "Build Highlight.js"
      system("cd node_modules/highlight.js && node tools/build.js -t cdn none")

      puts "Cleanup unused styles folder"
      system("rm -rf node_modules/highlight.js/build/styles")
    end

    if src.include? "ace-builds"
      puts "Cleanup unused snippets folder for ACE"
      system("rm -rf node_modules/ace-builds/src-min-noconflict/snippets")
    end

    if f[:public]
      dest = "#{public_js}/#{filename}"
    else
      dest = "#{vendor_js}/#{filename}"
    end

    # lodash.js needs building
    if src.include? "lodash.js"
      puts "Building custom lodash.js build"
      system('yarn run lodash include="each,filter,map,range,first,isEmpty,chain,extend,every,omit,merge,union,sortBy,uniq,intersection,reject,compact,reduce,debounce,throttle,values,pick,keys,flatten,min,max,isArray,delay,isString,isEqual,without,invoke,clone,findIndex,find,groupBy" minus="template" -d -o "node_modules/lodash.js"')
    end

    unless File.exists?(dest)
      STDERR.puts "New dependency added: #{dest}"
    end

    if f[:uglify]
      File.write(dest, Uglifier.new.compile(File.read(src)))
    else
      FileUtils.cp_r(src, dest)
    end
  end

  STDERR.puts "Completed copying dependencies: #{(Time.now - start).round(2)} secs"
end
