#
# application.coffee
#
window._ = require '../bower_components/lodash/dist/lodash'
require '../bower_components/datejs/build/date'

angular.module 'my-site', ['ionic']

  #
  # runtime
  #
  .run ($rootScope, $window, $state) ->

    #
    # inject loadash into $rootScope
    #
    $rootScope._ = $window._
