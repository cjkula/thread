var explorerApp = angular.module('explorerApp', ['ngRoute', 'explorerControllers']);

explorerApp.config(['$routeProvider',
  function($routeProvider) {
    $routeProvider.
      when('/', {
        templateUrl: 'partials/explorer/welcome.html'
      }).
      when('/transactions', {
        templateUrl: 'partials/explorer/transaction-list.html',
        controller: 'TransactionListCtrl'
      }).
      when('/transactions/new', {
        templateUrl: 'partials/explorer/transaction-new.html'
      }).
      when('/transactions/:uid', {
        templateUrl: 'partials/explorer/transaction-detail.html',
        controller: 'TransactionDetailCtrl'
      }).
      when('/keys', {
        templateUrl: 'partials/explorer/key-list.html',
        controller: 'KeyListCtrl'
      }).
      when('/keys/:base58', {
        templateUrl: 'partials/explorer/key-detail.html',
        controller: 'KeyDetailCtrl'
      }).
      otherwise({
        redirectTo: '/'
      });
  }]);
