#
# modules
#
fs         = require 'fs'
path       = require 'path'
gulp       = require 'gulp'
gutil      = require 'gulp-util'
jade       = require 'gulp-jade'
stylus     = require 'gulp-stylus'
CSSmin     = require 'gulp-minify-css'
streamify  = require 'gulp-streamify'
rename     = require 'gulp-rename'
uglify     = require 'gulp-uglify'
livereload = require 'gulp-livereload'
plumber    = require 'gulp-plumber'
prefix     = require 'gulp-autoprefixer'
header     = require 'gulp-header'
watch      = require 'gulp-watch'
cssbeautify= require 'gulp-cssbeautify'
replace    = require 'gulp-replace'
newer      = require 'gulp-newer'
imagemin   = require 'gulp-imagemin'
pngquant   = require 'imagemin-pngquant'
sh         = require 'execSync'
browserify = require 'browserify'
coffeeify  = require 'coffeeify'
csso       = require 'csso-stylus'
watchify   = require 'watchify'
ecstatic   = require 'ecstatic'
source     = require 'vinyl-source-stream'
lr         = require 'tiny-lr'
path       = require 'path'
argv       = require('minimist')(process.argv.slice(2))
reloadServer = lr()
noop       = gutil.noop

#
# Env
#
ENV = process.env.NODE_ENV || argv.env || argv.e || 'staging'
PRODUCTION = ENV is 'production'
APP_DIR = __dirname
ASSETS = "#{APP_DIR}/src"
TARGET = "#{APP_DIR}/build"
BOWER = "#{ASSETS}/bower_components"
LIVE_RELOAD_PORT = 35729
LOCAL_IP = ->
  sh.exec("ifconfig en0 | grep 'inet ' | tail -n 1 | cut -d ' ' -f 2")
    .stdout.replace(/\n/, '')
ENABLE_LIVERELOAD = argv.enableLiveReload || argv.l

#
# PATH definition
#
PATH =
  js:
    source: "#{ASSETS}/javascripts/application.coffee"
    watch:  "#{ASSETS}/javascripts/**/*.coffee"
    destination:
      filename: 'application.js'
      dir:     "#{TARGET}/js/"

  css:
    source: "#{ASSETS}/stylesheets/application.styl"
    watch:  "#{ASSETS}/stylesheets/**/*.styl"
    destination:
      dir: "#{TARGET}/css/"

  html:
    source: "#{ASSETS}/templates/*.jade"
    watch:  "#{ASSETS}/templates/**/*.jade"
    destination:
      dir: "#{TARGET}/"

  img:
    source: "#{ASSETS}/images/**/*.png"
    destination:
      dir: "#{TARGET}/img/"

  server: "#{TARGET}"

#
# error handler
#
handleError = (err) ->
  gutil.log err
  gutil.beep()
  this.emit 'end'

#
# Coffee to JavaScript build
#
gulp.task 'js', ->
  browserify
    entries: [PATH.js.source]
    extensions: ['.coffee']
  .bundle(debug: not PRODUCTION)
  .on 'error', handleError
  .pipe source PATH.js.destination.filename
  .pipe if PRODUCTION then streamify uglify(mangle: no) else noop()
  .pipe gulp.dest PATH.js.destination.dir
  .pipe livereload reloadServer

  gulp
    .src "#{BOWER}/ionic/release/js/ionic.bundle.min.js"
    .pipe if PRODUCTION then streamify uglify() else noop()
    .pipe gulp.dest PATH.js.destination.dir

#
# Stylus to CSS build
#
gulp.task 'css', ->
  gulp
    .src PATH.css.source
    .pipe stylus("include css": true, use: csso())
    .on 'error', handleError
    .pipe prefix('android >= 2.3', 'ios >= 6', 'last 2 Chrome versions')
    .pipe cssbeautify()
    .pipe gulp.dest PATH.css.destination.dir
    .pipe livereload reloadServer

  # copy ionic css, fonts
  gulp
    .src "#{BOWER}/ionic/release/css/ionic.min.css"
    .pipe gulp.dest PATH.css.destination.dir
  gulp
    .src "#{BOWER}/ionic/release/fonts/*"
    .pipe gulp.dest PATH.css.destination.dir + '../fonts'

#
# Jade to HTML build
#
gulp.task 'html', ->
  task = gulp
    .src PATH.html.source
    .pipe(jade(pretty: yes))
    .on 'error', handleError
    .pipe streamify replace /GULP_REPLACE_LOCAL_IP/, LOCAL_IP()

  if PRODUCTION && not ENABLE_LIVERELOAD
    # productionビルド時に不要なコードを削除
    # jadeの設定でproductionの時は1行のHTMLが生成されることに依存しているので注意
    task.pipe streamify replace /GULP_REMOVE_BEGIN.*GULP_REMOVE_END/g, ''

  task.pipe gulp.dest PATH.html.destination.dir
    .pipe livereload reloadServer

#
# Copy and minify images to build dir
#
gulp.task 'img', ->
  optimizer = [pngquant()]

  # iOS
  gulp
    .src PATH.img.source
    .pipe newer dest: PATH.img.destination.dir
    .pipe imagemin use: optimizer
    .pipe gulp.dest PATH.img.destination.dir
    .pipe livereload reloadServer

#
# local server for iOS directory
#
gulp.task 'local-server', ->
  require('http')
    .createServer ecstatic root: PATH.server
    .listen 9001

#
# watch [ Coffee | Sylus | Jade | Image ] files
#
gulp.task 'watch', ->
  # start LiveReload server listening port
  reloadServer.listen LIVE_RELOAD_PORT

  # relative pathじゃないと新規ファイルのwatchができない
  cwd = process.cwd()
  watch glob: path.relative(cwd, PATH.js.watch),   -> gulp.start 'js'
  watch glob: path.relative(cwd, PATH.css.watch),  -> gulp.start 'css'
  watch glob: path.relative(cwd, PATH.html.watch), -> gulp.start 'html'
  watch glob: path.relative(cwd, PATH.img.source), -> gulp.start 'img'

#
# task group
#
gulp.task "build", ['js', 'css', 'html', 'img']
gulp.task "default", ['build', 'watch', 'local-server']
