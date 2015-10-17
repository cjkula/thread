var spoolControllers = angular.module('spoolControllers', []);

spoolControllers.controller('NavigationCtrl', ['$scope', '$location',
  function ($scope, $location) {
    $scope.isCurrentPath = function (path) {
      return $location.path() == path;
    };
  }]);

spoolControllers.controller('TransactionListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $http.get('/api/transactions.json').success(function(data) {
      $scope.transactions = data;
    });

    $scope.orderProp = 'uid';
  }]);

spoolControllers.controller('TransactionDetailCtrl', ['$scope', '$routeParams', '$http',
  function($scope, $routeParams, $http) {
    function splitInto(chunkSize, string) {
      return string.match(new RegExp('.{1,' + chunkSize + '}', 'g'));
    }
    $http.get('/api/transactions/' + $routeParams.uid + '.json').success(function(data) {
      $scope.transaction = data;
      $scope.rawRows = _.map(splitInto(32, data.raw), function(row) {
        return _.map(splitInto(8, row), function(word) { return splitInto(2, word) });
      });
    });
  }]);

spoolControllers.controller('NewTransactionFormCtrl', ['$scope', '$http', '$location',
  function($scope, $http, $location) {
    $scope.transaction = {
      input: {},
      output: {}
    };
    $scope.submitForm = function() {
      $http.post('/api/transactions.json', $scope.transaction).then(function(response) {
        $location.path('/transactions/' + response.data.uid);
      });
    };
  }]);

function getAddresses() {
  var addresses = localStorage.getItem('thread_stash_addresses');
  return addresses ? JSON.parse(addresses) : [];
}

function getAddressByBase58(base58) {
  return _.find(getAddresses(), { 'base58': base58 });
}

spoolControllers.controller('AddressListCtrl', ['$scope', '$http',
  function($scope, $http) {
    $scope.addresses = getAddresses();

    $scope.generateAddress = function() {
      $http.get('/api/addresses/generate.json').success(function(data) {
        $scope.addresses.push(data);
        localStorage.setItem('thread_stash_addresses', JSON.stringify($scope.addresses));
      });
    };
  }]);

spoolControllers.controller('AddressDetailCtrl', ['$scope', '$routeParams',
  function($scope, $routeParams) {
    $scope.address = getAddressByBase58($routeParams.base58);
  }]);
