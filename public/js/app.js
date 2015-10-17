var spoolApp = angular.module('spoolApp', [
  'ngRoute',
  'spoolControllers'
]);

spoolApp.config(['$routeProvider',
  function($routeProvider) {
    $routeProvider.
      when('/', {
        templateUrl: 'partials/welcome.html'
      }).
      when('/transactions', {
        templateUrl: 'partials/transaction-list.html',
        controller: 'TransactionListCtrl'
      }).
      when('/transactions/new', {
        templateUrl: 'partials/transaction-new.html'
      }).
      when('/transactions/:uid', {
        templateUrl: 'partials/transaction-detail.html',
        controller: 'TransactionDetailCtrl'
      }).
      when('/addresses', {
        templateUrl: 'partials/address-list.html',
        controller: 'AddressListCtrl'
      }).
      when('/addresses/:base58', {
        templateUrl: 'partials/address-detail.html',
        controller: 'AddressDetailCtrl'
      }).
      otherwise({
        redirectTo: '/'
      });
  }]);

function activeFor() {
  return 'active';
}
